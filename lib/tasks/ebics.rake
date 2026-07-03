# frozen_string_literal: true

require "json"

namespace :ebics do
  desc "Print sanitized EBICS readiness report (optional TENANT=ragedevert LIVE_HEV=true)"
  task readiness: :environment do
    live_hev = ENV["LIVE_HEV"].in?(%w[1 true])
    tenant_name = ENV["TENANT"].presence || ENV["TENANT_NAME"].presence
    results = []

    if tenant_name
      abort "Tenant '#{tenant_name}' does not exist" unless Tenant.exists?(tenant_name)

      Tenant.switch(tenant_name) do
        results << Billing::EBICS::ReadinessReport.new(tenant: tenant_name, live_hev: live_hev).to_h
      end
    else
      Tenant.switch_each do |tenant|
        next if Tenant.custom? && !ENV["TENANT"]

        results << Billing::EBICS::ReadinessReport.new(tenant: tenant, live_hev: live_hev).to_h
      end
    end

    puts JSON.pretty_generate(
      live_hev: live_hev,
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
end
