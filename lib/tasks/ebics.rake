# frozen_string_literal: true

require "json"

namespace :ebics do
  desc "Print sanitized EBICS 3.0/H005 readiness report (optional TENANT=ragedevert; no live bank calls)"
  task readiness: :environment do
    tenant_name = ENV["TENANT"].presence || ENV["TENANT_NAME"].presence
    results = []

    if tenant_name
      abort "Tenant '#{tenant_name}' does not exist" unless Tenant.exists?(tenant_name)

      Tenant.switch(tenant_name) do
        results << Billing::EBICS::ReadinessReport.new(tenant: tenant_name).to_h
      end
    else
      Tenant.switch_each do |tenant|
        next if Tenant.custom? && !ENV["TENANT"]

        results << Billing::EBICS::ReadinessReport.new(tenant: tenant).to_h
      end
    end

    puts JSON.pretty_generate(results: results)
  end

  desc "Run EBICS capabilities monitor and print health summary (optional TENANT=ragedevert; live bank calls)"
  task monitor: :environment do
    tenant_name = ENV["TENANT"].presence || ENV["TENANT_NAME"].presence
    results = []

    if tenant_name
      abort "Tenant '#{tenant_name}' does not exist" unless Tenant.exists?(tenant_name)

      Tenant.switch(tenant_name) do
        results << monitor_capabilities_result(tenant_name, required: true)
      end
    else
      Tenant.switch_each do |tenant|
        result = monitor_capabilities_result(tenant)
        results << result if result
      end
    end

    puts JSON.pretty_generate(
      summary: results.map { |result| result.fetch("health_status") }.tally,
      results: results)
  end

  desc "Print sanitized H005 EBICS capabilities using HTD/HAA (TENANT required; live bank calls)"
  task capabilities: :environment do
    tenant_name = ENV["TENANT"].presence || ENV["TENANT_NAME"].presence

    abort "TENANT is required" unless tenant_name
    abort "Tenant '#{tenant_name}' does not exist" unless Tenant.exists?(tenant_name)

    Tenant.switch(tenant_name) do
      connection = Current.org.active_bank_connection
      abort "Tenant '#{tenant_name}' has no active EBICS bank connection" unless connection&.ebics?

      puts JSON.pretty_generate(
        Billing::EBICS::CapabilitiesReport.new(tenant: tenant_name, connection: connection).to_h)
    end
  end

  desc "Run a manual H005/BTF payment download test (TENANT, FROM, TO required; ACK=true acknowledges returned data)"
  task btf_download: :environment do
    tenant_name = ENV["TENANT"].presence || ENV["TENANT_NAME"].presence
    from = ENV["FROM"].presence
    to = ENV["TO"].presence
    acknowledge = ENV["ACK"].in?(%w[1 true])

    abort "TENANT is required" unless tenant_name
    abort "FROM is required (YYYY-MM-DD)" unless from
    abort "TO is required (YYYY-MM-DD)" unless to
    abort "Tenant '#{tenant_name}' does not exist" unless Tenant.exists?(tenant_name)

    Tenant.switch(tenant_name) do
      connection = Current.org.active_bank_connection
      abort "Tenant '#{tenant_name}' has no active EBICS bank connection" unless connection&.ebics?

      operation = Billing::EBICS::Operation.btf(
        Billing::EBICS::Btf::Presets.payment_download(country_code: Current.org.country_code))
      result = Billing::EBICS::BtfClient
        .new(connection.credentials)
        .test_download(operation, from: from, to: to, acknowledge: acknowledge)

      puts JSON.pretty_generate(
        tenant: tenant_name,
        from: from,
        to: to,
        acknowledge_requested: acknowledge,
        operation: operation.btf,
        result: result.to_h)
    end
  end

  def monitor_capabilities_result(tenant, required: false)
    connection = Current.org.active_bank_connection
    abort "Tenant '#{tenant}' has no active EBICS bank connection" if required && !connection&.ebics?
    return unless connection&.ebics?

    Billing::EBICS::CapabilitiesMonitor.new(connection: connection).check!
    connection.reload

    {
      "tenant" => tenant,
      "bank_connection_id" => connection.id,
      "bank" => connection.name,
      "health_status" => connection.health_status,
      "warnings" => connection.status_details.dig("last_capabilities_check", "warnings") || [],
      "last_health_check_at" => connection.last_health_check_at&.iso8601
    }
  end
end
