# frozen_string_literal: true

require "test_helper"
require "json"
require "minitest/mock"
require "rake"

class BillingRakeTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("billing:payments:process")
    Rake::Task["billing:health"].reenable
    Rake::Task["billing:payments:process"].reenable
    BankConnection.delete_all
  end

  test "health prints table with optional tenant and provider filters" do
    with_env("TENANTS" => "acme, demo", "PROVIDER" => "RAIFCHEC") do
      Tenant.stub(:exists?, ->(tenant) { tenant.in?(%w[acme demo]) }) do
        Billing::HealthReport.stub(:new, health_report_stub(expected_tenants: %w[acme demo], expected_provider: "RAIFCHEC")) do
          out, = capture_io { Rake::Task["billing:health"].invoke }

          assert_includes out, "billing health table"
        end
      end
    end
  end

  test "health reports unknown tenants" do
    with_env("TENANT" => "missing") do
      Tenant.stub(:exists?, false) do
        assert_raises(SystemExit) { capture_io { Rake::Task["billing:health"].invoke } }
      end
    end
  end

  test "payments process dry-run lists table-backed provider target without importing" do
    connection = create_connection(provider: "bas")

    with_env("PROVIDER" => "bas") do
      Tenant.stub(:switch_each, ->(&block) { block.call("acme") }) do
        Billing::PaymentsProcessor.stub(:retrieve_and_process!, -> { flunk "should not import without CONFIRM=true" }) do
          out, = capture_io { Rake::Task["billing:payments:process"].invoke }
          json = JSON.parse(out)

          assert_not json.fetch("confirmed")
          assert_equal({ "dry_run" => 1 }, json.fetch("summary"))
          assert_equal "acme", json.dig("results", 0, "tenant")
          assert_equal "bas", json.dig("results", 0, "provider")
          assert_equal "bank_connections", json.dig("results", 0, "source")
          assert_equal connection.id, json.dig("results", 0, "bank_connection_id")
        end
      end
    end
  end

  test "payments process runs selected tenant when confirmed" do
    connection = create_connection(provider: "bunq")

    with_env("TENANT" => "acme", "CONFIRM" => "true") do
      Tenant.stub(:exists?, true) do
        Tenant.stub(:switch, ->(_tenant, &block) { block.call }) do
          Billing::PaymentsProcessor.stub(:retrieve_and_process!, -> {
            operation = { "mode" => "provider_api", "provider" => "bunq", "kind" => "payment_import" }
            connection.mark_import_attempted!(operation: operation)
            connection.mark_no_data!(operation: operation)
            true
          }) do
            out, = capture_io { Rake::Task["billing:payments:process"].invoke }
            json = JSON.parse(out)

            assert json.fetch("confirmed")
            assert_equal({ "ok" => 1 }, json.fetch("summary"))
            assert_equal "acme", json.dig("results", 0, "tenant")
            assert_equal "bunq", json.dig("results", 0, "provider")
            assert_equal "healthy", json.dig("results", 0, "health_status")
            assert json.dig("results", 0, "last_import_attempted_at")
            assert json.dig("results", 0, "last_no_data_at")
          end
        end
      end
    end
  end

  test "payments process does not print provider exception text" do
    provider_text = "secret member@example.test <Document>payment data</Document>"
    create_connection(provider: "bunq")

    with_env("TENANT" => "acme", "CONFIRM" => "true") do
      Tenant.stub(:exists?, true) do
        Tenant.stub(:switch, ->(_tenant, &block) { block.call }) do
          Billing::PaymentsProcessor.stub(:retrieve_and_process!, -> { raise provider_text }) do
            out, = capture_io { Rake::Task["billing:payments:process"].invoke }
            json = JSON.parse(out)

            assert_equal "RuntimeError", json.dig("results", 0, "error_class")
            assert_not_includes out, provider_text
            assert_nil json.dig("results", 0, "last_error_message")
          end
        end
      end
    end
  end

  test "payments process filters by provider" do
    create_connection(provider: "bunq")

    with_env("PROVIDER" => "bas", "CONFIRM" => "true") do
      Tenant.stub(:switch_each, ->(&block) { block.call("acme") }) do
        Billing::PaymentsProcessor.stub(:retrieve_and_process!, -> { flunk "provider filter should skip bunq" }) do
          out, = capture_io { Rake::Task["billing:payments:process"].invoke }
          json = JSON.parse(out)

          assert_empty json.fetch("summary")
          assert_empty json.fetch("results")
        end
      end
    end
  end

  private

  def health_report_stub(expected_tenants:, expected_provider:)
    ->(tenant_names:, provider:) {
      assert_equal expected_tenants, tenant_names
      assert_equal expected_provider, provider

      Object.new.tap do |report|
        report.define_singleton_method(:table) { "billing health table" }
      end
    }
  end

  def create_connection(provider:)
    BankConnection.create!(
      provider: provider,
      name: provider.upcase,
      active: true,
      state: "ready",
      credentials: credentials_for(provider))
  end

  def credentials_for(provider)
    case provider
    when "bunq"
      {
        private_key: OpenSSL::PKey::RSA.new(2048).to_pem,
        installation_token: "test_installation_token",
        api_key: "test_api_key",
        user_id: 12345,
        monetary_account_id: 67890
      }
    else
      { account_number: "123", contract_password: "secret", password: "secret" }
    end
  end
end
