# frozen_string_literal: true

require "json"

namespace :ebics do
  namespace :key_rotation do
    desc "Print sanitized EBICS key-rotation readiness inventory (optional TENANT=ragedevert; no live bank calls)"
    task readiness: :environment do
      tenant_name = ENV["TENANT"].presence || ENV["TENANT_NAME"].presence
      results = []

      if tenant_name
        abort "Tenant '#{tenant_name}' does not exist" unless Tenant.exists?(tenant_name)

        Tenant.switch(tenant_name) do
          results << Billing::EBICS::KeyRotation.new(tenant: tenant_name).readiness
        end
      else
        Tenant.switch_each do |tenant|
          next if Tenant.custom? && !ENV["TENANT"]
          next unless Current.org.active_bank_connection&.ebics?

          results << Billing::EBICS::KeyRotation.new(tenant: tenant).readiness
        end
      end

      puts JSON.pretty_generate(
        summary: results.map { |result| result.fetch("state") }.tally,
        results: results)
    end

    desc "Prepare encrypted pending 4096-bit EBICS participant keys (TENANT and CONFIRM=true required; no live bank calls)"
    task prepare: :environment do
      require_confirmation!
      puts JSON.pretty_generate(with_key_rotation(&:prepare_pending!))
    end

    desc "Validate local EBICS key-rotation request-build prerequisites (TENANT required; sanitized metadata only)"
    task validate: :environment do
      puts JSON.pretty_generate(key_rotation_request_build_validation)
    end

    desc "Alias for ebics:key_rotation:validate"
    task build: :environment do
      puts JSON.pretty_generate(key_rotation_request_build_validation)
    end

    desc "Submit pending EBICS HCS key rotation to the bank (TENANT and CONFIRM=true required; live bank call)"
    task submit: :environment do
      require_confirmation!
      puts JSON.pretty_generate(with_key_rotation(&:submit_pending!))
    end

    desc "Verify pending EBICS keys with HTD (TENANT and CONFIRM=true required; live bank call, no credential promotion)"
    task verify: :environment do
      require_confirmation!
      puts JSON.pretty_generate(with_key_rotation(&:verify_pending!))
    end

    desc "Promote verified pending EBICS keys locally (TENANT and CONFIRM=true required; no live bank call)"
    task promote: :environment do
      require_confirmation!
      puts JSON.pretty_generate(with_key_rotation(&:promote_pending!))
    end

    desc "Prepare, submit, verify, and promote EBICS HCS key rotation (TENANT and CONFIRM=true required; live bank calls)"
    task perform: :environment do
      require_confirmation!
      puts JSON.pretty_generate(with_key_rotation(&:perform!))
    end

    desc "Rotate EBICS keys back to the previous encrypted key set (TENANT and CONFIRM=true required; live bank call)"
    task rollback: :environment do
      require_confirmation!
      puts JSON.pretty_generate(with_key_rotation(&:rollback!))
    end

    desc "Recover a rollback after HCS may have succeeded but local promotion did not (TENANT and CONFIRM=true required; live bank call, no HCS)"
    task recover_rollback: :environment do
      require_confirmation!
      puts JSON.pretty_generate(with_key_rotation(&:recover_rollback!))
    end

    desc "Discard pending EBICS key rotation without changing active keys (TENANT and CONFIRM=true required; no live bank call)"
    task discard_pending: :environment do
      require_confirmation!
      reason = ENV["REASON"].presence || "manual_discard"
      puts JSON.pretty_generate(with_key_rotation { |rotation| rotation.discard_pending!(reason: reason) })
    end

    namespace :batch do
      desc "Plan EBICS key rotation for selected tenants (optional TENANTS=..., PROVIDER=RAIFCHEC/ebics; no live bank calls)"
      task plan: :environment do
        puts JSON.pretty_generate(key_rotation_batch.plan)
      end

      desc "Prepare pending EBICS keys for selected tenants (TENANTS=..., PROVIDER=..., or ALL=true; CONFIRM=true required; no live bank calls)"
      task prepare: :environment do
        require_batch_selection!
        require_confirmation!
        puts JSON.pretty_generate(key_rotation_batch.prepare!)
      end

      desc "Prepare, submit, verify, and promote EBICS keys for selected tenants (TENANTS=..., PROVIDER=..., or ALL=true; CONFIRM=true required; live bank calls)"
      task perform: :environment do
        require_batch_selection!
        require_confirmation!
        puts JSON.pretty_generate(key_rotation_batch.perform!)
      end
    end
  end

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

  def key_rotation_request_build_validation
    with_key_rotation(&:request_build_validation)
  end

  def key_rotation_batch
    Billing::EBICS::KeyRotationBatch.new(
      tenant_names: key_rotation_batch_tenant_names,
      provider: ENV["PROVIDER"].presence,
      all: truthy_env?("ALL"),
      verify_payments: truthy_env?("VERIFY_PAYMENTS"))
  end

  def key_rotation_batch_tenant_names
    (ENV["TENANTS"].presence || ENV["TENANT"].presence || ENV["TENANT_NAME"].presence)
      .to_s
      .split(/[,\s]+/)
      .compact_blank
  end

  def require_batch_selection!
    return if key_rotation_batch_tenant_names.present?
    return if ENV["PROVIDER"].present?
    return if truthy_env?("ALL")

    abort "Set TENANTS, PROVIDER, or ALL=true"
  end

  def with_key_rotation
    tenant_name = ENV["TENANT"].presence || ENV["TENANT_NAME"].presence

    abort "TENANT is required" unless tenant_name
    abort "Tenant '#{tenant_name}' does not exist" unless Tenant.exists?(tenant_name)

    result = nil
    Tenant.switch(tenant_name) do
      connection = Current.org.active_bank_connection
      abort "Tenant '#{tenant_name}' has no active EBICS bank connection" unless connection&.ebics?

      result = yield Billing::EBICS::KeyRotation.new(tenant: tenant_name, connection: connection)
    end
    result
  end

  def require_confirmation!
    abort "CONFIRM=true is required" unless truthy_env?("CONFIRM")
  end

  def truthy_env?(key)
    ENV[key].in?(%w[1 true yes])
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
