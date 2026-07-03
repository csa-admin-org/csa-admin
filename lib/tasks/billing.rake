# frozen_string_literal: true

require "json"

namespace :billing do
  namespace :payments do
    desc "Run live payment import processing (TENANT=..., PROVIDER=..., or ALL=true; CONFIRM=true required to execute)"
    task process: :environment do
      tenant_name = ENV["TENANT"].presence || ENV["TENANT_NAME"].presence
      provider = ENV["PROVIDER"].presence
      confirm = ENV["CONFIRM"].in?(%w[1 true yes])
      all = ENV["ALL"].in?(%w[1 true yes])

      abort "Set TENANT, PROVIDER, or ALL=true" unless tenant_name || provider || all
      abort "Unsupported PROVIDER=#{provider}" if provider && !provider.in?(BankConnection::PROVIDERS)

      results = []
      if tenant_name
        abort "Tenant '#{tenant_name}' does not exist" unless Tenant.exists?(tenant_name)

        Tenant.switch(tenant_name) do
          results << payment_import_process_result(tenant_name, provider:, confirm:, required: true)
        end
      else
        Tenant.switch_each do |tenant|
          next if Tenant.custom? && !ENV["TENANT"]

          result = payment_import_process_result(tenant, provider:, confirm:)
          results << result if result
        end
      end

      puts JSON.pretty_generate(
        checked_at: Time.current.iso8601,
        confirmed: confirm,
        filters: {
          tenant: tenant_name,
          provider: provider,
          all: all
        }.compact,
        summary: results.map { |result| result.fetch("status") }.tally,
        results: results)
    end
  end

  def payment_import_process_result(tenant, provider:, confirm:, required: false)
    connection = Current.org.active_bank_connection
    resolved_provider = connection&.provider

    abort "Tenant '#{tenant}' has no active bank connection" if required && !connection
    return unless connection
    return if provider && provider != resolved_provider

    unless confirm
      return payment_import_result(tenant, connection:, provider: resolved_provider, source: "bank_connections", status: "dry_run")
    end

    Billing::PaymentsProcessor.retrieve_and_process!
    connection.reload
    payment_import_result(tenant, connection:, provider: resolved_provider, source: "bank_connections", status: "ok")
  rescue => e
    connection&.reload
    payment_import_result(tenant,
      connection: connection,
      provider: resolved_provider,
      source: "bank_connections",
      status: "error",
      error_class: e.class.name,
      error_message: e.message.to_s.truncate(500))
  end

  def payment_import_result(tenant, provider:, source:, status:, connection: nil, **attributes)
    {
      "tenant" => tenant,
      "provider" => provider,
      "source" => source,
      "status" => status,
      "bank_connection_id" => connection&.id,
      "bank" => connection&.name,
      "health_status" => connection&.health_status,
      "last_health_check_at" => connection&.last_health_check_at&.iso8601,
      "last_import_attempted_at" => connection&.last_import_attempted_at&.iso8601,
      "last_import_succeeded_at" => connection&.last_import_succeeded_at&.iso8601,
      "last_no_data_at" => connection&.last_no_data_at&.iso8601,
      "last_error_class" => connection&.last_error_class,
      "last_error_message" => connection&.last_error_message
    }.merge(attributes.stringify_keys).compact
  end
end
