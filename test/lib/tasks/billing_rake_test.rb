# frozen_string_literal: true

require "test_helper"
require "json"
require "rake"

class BillingRakeTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("billing:payments:process")
    Rake::Task["billing:payments:process"].reenable
    BankConnection.delete_all
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

  test "payments process reports legacy fallback without importing" do
    org(bank_connection_type: "mock", bank_credentials: { password: "secret" })

    with_env("TENANT" => "acme", "CONFIRM" => "true") do
      Tenant.stub(:exists?, true) do
        Tenant.stub(:switch, ->(_tenant, &block) { block.call }) do
          Billing::PaymentsProcessor.stub(:retrieve_and_process!, -> { flunk "should not import legacy fallback" }) do
            out, = capture_io { Rake::Task["billing:payments:process"].invoke }
            json = JSON.parse(out)

            assert_equal({ "legacy_fallback" => 1 }, json.fetch("summary"))
            assert_equal "mock", json.dig("results", 0, "provider")
            assert_equal "legacy_organization", json.dig("results", 0, "source")
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
