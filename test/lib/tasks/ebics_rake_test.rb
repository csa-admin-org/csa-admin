# frozen_string_literal: true

require "test_helper"
require "json"
require "minitest/mock"
require "rake"

class EbicsRakeTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("ebics:readiness")
    Rake::Task["ebics:readiness"].reenable
    Rake::Task["ebics:monitor"].reenable
    Rake::Task["ebics:capabilities"].reenable
    Rake::Task["ebics:btf_download"].reenable
    Rake::Task["ebics:onboarding:status"].reenable
    Rake::Task["ebics:onboarding:initialize"].reenable
    Rake::Task["ebics:onboarding:letter"].reenable
    Rake::Task["ebics:onboarding:submit_ini"].reenable
    Rake::Task["ebics:onboarding:submit_hia"].reenable
    Rake::Task["ebics:onboarding:finalize"].reenable
    Rake::Task["ebics:sepa_direct_debit:confirm_not_accepted"].reenable
    Rake::Task["ebics:key_rotation:readiness"].reenable
    Rake::Task["ebics:key_rotation:prepare"].reenable
    Rake::Task["ebics:key_rotation:validate"].reenable
    Rake::Task["ebics:key_rotation:build"].reenable
    Rake::Task["ebics:key_rotation:submit"].reenable
    Rake::Task["ebics:key_rotation:verify"].reenable
    Rake::Task["ebics:key_rotation:promote"].reenable
    Rake::Task["ebics:key_rotation:perform"].reenable
    Rake::Task["ebics:key_rotation:discard_pending"].reenable
    Rake::Task["ebics:key_rotation:purge_previous"].reenable
    Rake::Task["ebics:key_rotation:batch:plan"].reenable
    Rake::Task["ebics:key_rotation:batch:prepare"].reenable
    Rake::Task["ebics:key_rotation:batch:perform"].reenable
    BankConnection.delete_all
  end

  test "readiness prints sanitized tenant report as JSON" do
    with_env("TENANT" => "ragedevert") do
      Tenant.stub(:exists?, true) do
        Tenant.stub(:switch, ->(_tenant, &block) { block.call }) do
          Billing::EBICS::ReadinessReport.stub(:new, readiness_report_stub) do
            out, = capture_io { Rake::Task["ebics:readiness"].invoke }
            json = JSON.parse(out)

            assert_equal [ { "tenant" => "ragedevert", "ebics" => { "protocol" => "H005" } } ], json.fetch("results")
          end
        end
      end
    end
  end

  test "onboarding status prints sanitized tenant report as JSON" do
    org(country_code: "CH")
    BankConnection.create!(provider: "ebics", name: "HOSTID", state: "initializing")

    with_env("TENANT" => "ragedevert") do
      Tenant.stub(:exists?, true) do
        Tenant.stub(:switch, ->(_tenant, &block) { block.call }) do
          Billing::EBICS::Onboarding.stub(:new, onboarding_stub) do
            out, = capture_io { Rake::Task["ebics:onboarding:status"].invoke }
            json = JSON.parse(out)

            assert_equal "ragedevert", json.fetch("tenant")
            assert_equal "initialized", json.fetch("state")
            assert_equal "HOSTID", json.dig("group", "host_id")
          end
        end
      end
    end
  end

  test "onboarding initialize requires confirmation and endpoint ids" do
    with_env("TENANT" => "ragedevert", "CONFIRM" => nil) do
      Tenant.stub(:exists?, true) do
        assert_raises(SystemExit) { capture_io { Rake::Task["ebics:onboarding:initialize"].invoke } }
      end
    end

    with_env("TENANT" => "ragedevert", "CONFIRM" => "true", "URL" => nil) do
      Rake::Task["ebics:onboarding:initialize"].reenable
      Tenant.stub(:exists?, true) do
        Tenant.stub(:switch, ->(_tenant, &block) { block.call }) do
          assert_raises(SystemExit) { capture_io { Rake::Task["ebics:onboarding:initialize"].invoke } }
        end
      end
    end
  end

  test "onboarding initialize calls backend when confirmed" do
    with_env("TENANT" => "ragedevert", "CONFIRM" => "true", "URL" => "https://ebics.example.test", "HOST_ID" => "HOSTID", "CLIENT_ID" => "CLIENTID", "PARTICIPANT_ID" => "PARTICIPANTID", "NAME" => "Test Bank", "KEY_BITS" => "2048") do
      Tenant.stub(:exists?, true) do
        Tenant.stub(:switch, ->(_tenant, &block) { block.call }) do
          Billing::EBICS::Onboarding.stub(:new, onboarding_stub) do
            out, = capture_io { Rake::Task["ebics:onboarding:initialize"].invoke }
            json = JSON.parse(out)

            assert json.fetch("initialized")
            assert_equal "initialized", json.fetch("state")
          end
        end
      end
    end
  end

  test "onboarding letter and live tasks call backend with guards" do
    org(country_code: "CH")
    BankConnection.create!(provider: "ebics", name: "HOSTID", state: "initializing")

    %w[submit_ini submit_hia finalize].each do |task_name|
      with_env("TENANT" => "ragedevert", "CONFIRM" => nil) do
        Rake::Task["ebics:onboarding:#{task_name}"].reenable
        assert_raises(SystemExit) { capture_io { Rake::Task["ebics:onboarding:#{task_name}"].invoke } }
      end
    end

    with_env("TENANT" => "ragedevert", "OUTPUT" => Rails.root.join("tmp/test-ebics-letter.pdf").to_s, "CONFIRM" => nil) do
      Tenant.stub(:exists?, true) do
        Tenant.stub(:switch, ->(_tenant, &block) { block.call }) do
          Billing::EBICS::Onboarding.stub(:new, onboarding_stub) do
            out, = capture_io { Rake::Task["ebics:onboarding:letter"].invoke }
            json = JSON.parse(out)

            assert_equal "letter", json.fetch("task")
          end
        end
      end
    end

    %w[submit_ini submit_hia finalize].each do |task_name|
      with_env("TENANT" => "ragedevert", "CONFIRM" => "true") do
        Rake::Task["ebics:onboarding:#{task_name}"].reenable
        Tenant.stub(:exists?, true) do
          Tenant.stub(:switch, ->(_tenant, &block) { block.call }) do
            Billing::EBICS::Onboarding.stub(:new, onboarding_stub) do
              out, = capture_io { Rake::Task["ebics:onboarding:#{task_name}"].invoke }
              json = JSON.parse(out)

              assert_equal task_name, json.fetch("task")
            end
          end
        end
      end
    end
  end

  test "SEPA direct debit reconciliation requires bank confirmation before unlocking retry" do
    invoice = invoices(:annual_fee)
    invoice.update_columns(
      sepa_direct_debit_submission_state: "uncertain",
      sepa_direct_debit_submission_attempted_at: Time.current,
      sepa_direct_debit_pain_message_id: "CSAADMIN/uncertain-attempt",
      sepa_direct_debit_pain_payload_sha256: "a" * 64)

    with_env("TENANT" => "ragedevert", "INVOICE_ID" => invoice.id.to_s, "CONFIRM" => nil) do
      assert_raises(SystemExit) do
        capture_io { Rake::Task["ebics:sepa_direct_debit:confirm_not_accepted"].invoke }
      end
    end

    Rake::Task["ebics:sepa_direct_debit:confirm_not_accepted"].reenable
    with_env(
      "TENANT" => "ragedevert",
      "INVOICE_ID" => invoice.id.to_s,
      "CONFIRM" => "true",
      "BANK_CONFIRMED_NOT_ACCEPTED" => "true") do
      Tenant.stub(:exists?, true) do
        Tenant.stub(:switch, ->(_tenant, &block) { block.call }) do
          out, = capture_io { Rake::Task["ebics:sepa_direct_debit:confirm_not_accepted"].invoke }
          json = JSON.parse(out)

          assert_equal invoice.id, json.fetch("invoice_id")
          assert_equal "failed", json.fetch("submission_state")
          assert json.fetch("payload_identity_preserved")
        end
      end
    end
  end

  test "key rotation readiness prints sanitized inventory as JSON" do
    with_env("TENANT" => "ragedevert") do
      Tenant.stub(:exists?, true) do
        Tenant.stub(:switch, ->(_tenant, &block) { block.call }) do
          Billing::EBICS::KeyRotation.stub(:new, key_rotation_stub) do
            out, = capture_io { Rake::Task["ebics:key_rotation:readiness"].invoke }
            json = JSON.parse(out)

            assert_equal({ "unknown" => 1 }, json.fetch("summary"))
            assert_equal "ragedevert", json.dig("results", 0, "tenant")
            assert_equal "HOSTID", json.dig("results", 0, "group", "host_id")
            assert_equal "unknown", json.dig("results", 0, "state")
          end
        end
      end
    end
  end

  test "key rotation prepare requires confirmation" do
    with_env("TENANT" => "ragedevert", "CONFIRM" => nil) do
      Tenant.stub(:exists?, true) do
        assert_raises(SystemExit) { capture_io { Rake::Task["ebics:key_rotation:prepare"].invoke } }
      end
    end
  end

  test "key rotation prepare stores pending keys through model" do
    org(country_code: "CH")
    BankConnection.create!(
      provider: "ebics",
      name: "HOSTID",
      active: true,
      state: "ready",
      credentials: ebics_credentials,
      settings: active_payment_settings)

    with_env("TENANT" => "ragedevert", "CONFIRM" => "true") do
      Tenant.stub(:exists?, true) do
        Tenant.stub(:switch, ->(_tenant, &block) { block.call }) do
          Billing::EBICS::KeyRotation.stub(:new, key_rotation_stub) do
            out, = capture_io { Rake::Task["ebics:key_rotation:prepare"].invoke }
            json = JSON.parse(out)

            assert json.fetch("prepared")
            assert_equal "pending_rotation", json.fetch("state")
          end
        end
      end
    end
  end

  test "key rotation validate prints sanitized request-build metadata" do
    org(country_code: "CH")
    BankConnection.create!(
      provider: "ebics",
      name: "HOSTID",
      active: true,
      state: "ready",
      credentials: ebics_credentials,
      settings: active_payment_settings)

    with_env("TENANT" => "ragedevert") do
      Tenant.stub(:exists?, true) do
        Tenant.stub(:switch, ->(_tenant, &block) { block.call }) do
          Billing::EBICS::KeyRotation.stub(:new, key_rotation_stub) do
            out, = capture_io { Rake::Task["ebics:key_rotation:validate"].invoke }
            json = JSON.parse(out)

            assert_equal "ok", json.fetch("status")
            assert_equal "HCS", json.dig("safe_metadata", "request", "order_type")
          end
        end
      end
    end
  end

  test "key rotation submit verify promote perform and discard tasks call model with guards" do
    %w[submit verify promote perform discard_pending purge_previous].each do |task_name|
      with_env("TENANT" => "ragedevert", "CONFIRM" => nil) do
        Rake::Task["ebics:key_rotation:#{task_name}"].reenable
        assert_raises(SystemExit) { capture_io { Rake::Task["ebics:key_rotation:#{task_name}"].invoke } }
      end
    end

    %w[submit verify promote perform discard_pending purge_previous].each do |task_name|
      assert_key_rotation_task(task_name)
    end
  end

  test "key rotation batch plan passes filters to coordinator without confirmation" do
    with_env("TENANTS" => "tapatate, clefdeschamps", "PROVIDER" => "RAIFCHEC", "ALL" => "true", "VERIFY_PAYMENTS" => "true", "CONFIRM" => nil) do
      Billing::EBICS::KeyRotationBatch.stub(:new, key_rotation_batch_stub(expected_method: :plan)) do
        out, = capture_io { Rake::Task["ebics:key_rotation:batch:plan"].invoke }
        json = JSON.parse(out)

        assert_equal "plan", json.fetch("action")
      end
    end
  end

  test "key rotation batch prepare requires selection and confirmation" do
    with_env("TENANTS" => nil, "PROVIDER" => nil, "ALL" => nil, "CONFIRM" => "true") do
      assert_raises(SystemExit) { capture_io { Rake::Task["ebics:key_rotation:batch:prepare"].invoke } }
    end

    with_env("TENANTS" => "tapatate", "PROVIDER" => nil, "ALL" => nil, "CONFIRM" => nil) do
      Rake::Task["ebics:key_rotation:batch:prepare"].reenable
      assert_raises(SystemExit) { capture_io { Rake::Task["ebics:key_rotation:batch:prepare"].invoke } }
    end
  end

  test "key rotation batch perform requires a single tenant and confirmation" do
    [
      { "TENANT" => nil, "TENANTS" => nil, "PROVIDER" => nil, "ALL" => nil, "CONFIRM" => "true" },
      { "TENANT" => nil, "TENANTS" => "tapatate", "PROVIDER" => nil, "ALL" => nil, "CONFIRM" => "true" },
      { "TENANT" => nil, "TENANTS" => nil, "PROVIDER" => "RAIFCHEC", "ALL" => nil, "CONFIRM" => "true" },
      { "TENANT" => nil, "TENANTS" => nil, "PROVIDER" => nil, "ALL" => "true", "CONFIRM" => "true" },
      { "TENANT" => "tapatate", "TENANTS" => nil, "PROVIDER" => nil, "ALL" => nil, "CONFIRM" => nil }
    ].each do |env|
      with_env(env) do
        Rake::Task["ebics:key_rotation:batch:perform"].reenable
        assert_raises(SystemExit) { capture_io { Rake::Task["ebics:key_rotation:batch:perform"].invoke } }
      end
    end
  end

  test "key rotation batch prepare calls coordinator when confirmed" do
    with_env("TENANTS" => nil, "PROVIDER" => "RAIFCHEC", "ALL" => nil, "VERIFY_PAYMENTS" => "true", "CONFIRM" => "true") do
      Billing::EBICS::KeyRotationBatch.stub(:new, key_rotation_batch_stub(expected_method: :prepare!, expected_tenants: [], expected_provider: "RAIFCHEC", expected_all: false, expected_verify_payments: true)) do
        out, = capture_io { Rake::Task["ebics:key_rotation:batch:prepare"].invoke }
        json = JSON.parse(out)

        assert_equal "prepare", json.fetch("action")
      end
    end
  end

  test "key rotation batch perform calls coordinator for one confirmed tenant" do
    with_env("TENANT" => "tapatate", "TENANTS" => nil, "PROVIDER" => nil, "ALL" => nil, "VERIFY_PAYMENTS" => "true", "CONFIRM" => "true") do
      Billing::EBICS::KeyRotationBatch.stub(:new, key_rotation_batch_stub(expected_method: :perform!, expected_tenants: [ "tapatate" ], expected_provider: nil, expected_all: false, expected_verify_payments: true)) do
        out, = capture_io { Rake::Task["ebics:key_rotation:batch:perform"].invoke }
        json = JSON.parse(out)

        assert_equal "perform", json.fetch("action")
      end
    end
  end

  test "monitor runs capabilities monitor and prints health summary" do
    org(country_code: "DE")
    BankConnection.create!(
      provider: "ebics",
      name: "MULTIVIA",
      active: true,
      state: "ready",
      credentials: ebics_credentials,
      settings: active_payment_settings)

    with_env("TENANT" => "wilderauke") do
      Tenant.stub(:exists?, true) do
        Tenant.stub(:switch, ->(_tenant, &block) { block.call }) do
          Billing::EBICS::CapabilitiesMonitor.stub(:new, capabilities_monitor_stub) do
            out, = capture_io { Rake::Task["ebics:monitor"].invoke }
            json = JSON.parse(out)

            assert_equal({ "healthy" => 1 }, json.fetch("summary"))
            assert_equal "wilderauke", json.dig("results", 0, "tenant")
            assert_equal "MULTIVIA", json.dig("results", 0, "bank")
            assert_equal "healthy", json.dig("results", 0, "health_status")
            assert_empty json.dig("results", 0, "warnings")
          end
        end
      end
    end
  end

  test "capabilities prints sanitized H005 admin order report as JSON" do
    org(country_code: "DE")
    BankConnection.create!(
      provider: "ebics",
      name: "MULTIVIA",
      active: true,
      state: "ready",
      credentials: ebics_credentials,
      settings: active_payment_settings)

    with_env("TENANT" => "wilderauke") do
      Tenant.stub(:exists?, true) do
        Tenant.stub(:switch, ->(_tenant, &block) { block.call }) do
          Billing::EBICS::CapabilitiesReport.stub(:new, capabilities_report_stub) do
            out, = capture_io { Rake::Task["ebics:capabilities"].invoke }
            json = JSON.parse(out)

            assert_equal "wilderauke", json.fetch("tenant")
            assert_equal "MULTIVIA", json.dig("active_connection", "name")
            assert_equal "ok", json.dig("h005", "admin_orders", "HTD", "status")
          end
        end
      end
    end
  end

  test "btf_download prints manual dry-run result as JSON" do
    org(country_code: "CH")
    BankConnection.create!(
      provider: "ebics",
      active: true,
      state: "ready",
      credentials: ebics_credentials,
      settings: active_payment_settings)

    with_env("TENANT" => "ragedevert", "FROM" => "2026-06-01", "TO" => "2026-06-02", "ACK" => "false") do
      Tenant.stub(:exists?, true) do
        Tenant.stub(:switch, ->(_tenant, &block) { block.call }) do
          Billing::EBICS::BtfClient.stub(:new, btf_client_stub) do
            out, = capture_io { Rake::Task["ebics:btf_download"].invoke }
            json = JSON.parse(out)

            assert_equal "ragedevert", json.fetch("tenant")
            assert_equal "2026-06-01", json.fetch("from")
            assert_equal "2026-06-02", json.fetch("to")
            assert_not json.fetch("acknowledge_requested")
            assert_equal "BTD", json.dig("operation", "order_type")
            assert_equal "camt.053", json.dig("operation", "message_name")
            assert_equal "DE", json.dig("operation", "scope")
            assert_nil json.dig("operation", "version")
            assert_equal "data_available_not_acknowledged", json.dig("result", "status")
            assert_equal 1, json.dig("result", "receipt_code")
          end
        end
      end
    end
  end

  private

  def assert_key_rotation_task(task_name)
    org(country_code: "CH")
    BankConnection.delete_all
    BankConnection.create!(
      provider: "ebics",
      name: "HOSTID",
      active: true,
      state: "ready",
      credentials: ebics_credentials,
      settings: active_payment_settings)

    env = { "TENANT" => "ragedevert", "CONFIRM" => "true" }

    with_env(env) do
      Tenant.stub(:exists?, true) do
        Tenant.stub(:switch, ->(_tenant, &block) { block.call }) do
          Billing::EBICS::KeyRotation.stub(:new, key_rotation_stub) do
            Rake::Task["ebics:key_rotation:#{task_name}"].reenable
            out, = capture_io { Rake::Task["ebics:key_rotation:#{task_name}"].invoke }
            json = JSON.parse(out)

            assert_equal task_name, json.fetch("task")
          end
        end
      end
    end
  end

  def ebics_credentials
    @ebics_credentials ||= synthetic_ebics_credentials(
      user_id: "PARTICIPANTID",
      partner_id: "CLIENTID")
  end

  def btf_client_stub
    test = self
    ->(_credentials) {
      Object.new.tap do |client|
        client.define_singleton_method(:test_download) do |operation, from:, to:, acknowledge:|
          test.assert_equal "BTD", operation.order_type
          test.assert_equal "EOP", operation.btf.fetch("service_name")
          test.assert_equal "DE", operation.btf.fetch("scope")
          test.assert_equal "camt.053", operation.btf.fetch("message_name")
          test.assert_nil operation.btf["version"]
          test.assert_equal "2026-06-01", from
          test.assert_equal "2026-06-02", to
          test.assert_not acknowledge

          Struct.new(:to_h).new({
            "status" => "data_available_not_acknowledged",
            "files_count" => 1,
            "bytes" => 123,
            "acknowledged" => false,
            "receipt_code" => 1
          })
        end
      end
    }
  end

  def active_payment_settings
    {
      "protocol" => "H005",
      "downloads" => {
        "payments" => {
          "mode" => "btf",
          "btf" => Billing::EBICS::Btf::Presets.camt053(service_name: "EOP", scope: "DE")
        }
      }
    }
  end

  def capabilities_monitor_stub
    ->(connection:) {
      assert_equal "MULTIVIA", connection.name
      Object.new.tap do |monitor|
        monitor.define_singleton_method(:check!) do
          connection.mark_capabilities_checked!(
            report: { "country_code" => "DE", "h005" => {} },
            status: "healthy",
            warnings: [])
        end
      end
    }
  end

  def onboarding_stub
    test = self
    ->(connection: nil) {
      tenant = "ragedevert"

      Object.new.tap do |onboarding|
        onboarding.define_singleton_method(:connection) { connection || BankConnection.first }
        onboarding.define_singleton_method(:status) do
          {
            "tenant" => tenant,
            "state" => "initialized",
            "group" => {
              "host_id" => "HOSTID"
            }
          }
        end
        onboarding.define_singleton_method(:initialize_connection!) do |url:, host_id:, client_id:, participant_id:, name:, target_bits:|
          test.assert_equal "https://ebics.example.test", url
          test.assert_equal "HOSTID", host_id
          test.assert_equal "CLIENTID", client_id
          test.assert_equal "PARTICIPANTID", participant_id
          test.assert_equal "Test Bank", name
          test.assert_equal "2048", target_bits
          status.merge("initialized" => true)
        end
        onboarding.define_singleton_method(:write_letter!) do |output:, locale:|
          {
            "task" => "letter",
            "output" => output,
            "locale" => locale.to_s
          }
        end
        onboarding.define_singleton_method(:submit_ini!) do
          { "task" => "submit_ini" }
        end
        onboarding.define_singleton_method(:submit_hia!) do
          { "task" => "submit_hia" }
        end
        onboarding.define_singleton_method(:finalize!) do
          { "task" => "finalize" }
        end
      end
    }
  end

  def key_rotation_stub
    ->(tenant:, connection: nil) {
      assert_equal "ragedevert", tenant
      assert_nil connection unless connection

      Object.new.tap do |rotation|
        rotation.define_singleton_method(:readiness) do
          {
            "tenant" => tenant,
            "group" => {
              "host_id" => "HOSTID"
            },
            "state" => "unknown"
          }
        end
        rotation.define_singleton_method(:prepare_pending!) do
          {
            "tenant" => tenant,
            "state" => "pending_rotation",
            "prepared" => true
          }
        end
        rotation.define_singleton_method(:request_build_validation) do
          {
            "tenant" => tenant,
            "status" => "ok",
            "safe_metadata" => {
              "request" => {
                "order_type" => "HCS"
              }
            }
          }
        end
        rotation.define_singleton_method(:submit_pending!) do
          { "task" => "submit" }
        end
        rotation.define_singleton_method(:verify_pending!) do
          { "task" => "verify" }
        end
        rotation.define_singleton_method(:promote_pending!) do
          { "task" => "promote" }
        end
        rotation.define_singleton_method(:perform!) do
          { "task" => "perform" }
        end

        rotation.define_singleton_method(:discard_pending!) do |reason:|
          { "task" => "discard_pending", "reason" => reason }
        end

        rotation.define_singleton_method(:purge_previous!) do |reason:|
          { "task" => "purge_previous", "reason" => reason }
        end
      end
    }
  end

  def key_rotation_batch_stub(expected_method:, expected_tenants: %w[tapatate clefdeschamps], expected_provider: "RAIFCHEC", expected_all: true, expected_verify_payments: true)
    ->(tenant_names:, provider:, all:, verify_payments:) {
      assert_equal expected_tenants, tenant_names
      assert_equal expected_provider, provider
      assert_equal expected_all, all
      assert_equal expected_verify_payments, verify_payments

      Object.new.tap do |batch|
        batch.define_singleton_method(expected_method) do
          {
            "action" => expected_method.to_s.delete_suffix("!"),
            "summary" => {},
            "results" => []
          }
        end
      end
    }
  end

  def capabilities_report_stub
    ->(tenant:, connection:) {
      assert_equal "wilderauke", tenant
      assert_equal "MULTIVIA", connection.name
      Struct.new(:to_h).new({
        "tenant" => tenant,
        "active_connection" => {
          "name" => connection.name
        },
        "h005" => {
          "admin_orders" => {
            "HTD" => {
              "status" => "ok"
            }
          }
        }
      })
    }
  end

  def readiness_report_stub
    ->(tenant:) {
      assert_equal "ragedevert", tenant
      Struct.new(:to_h).new({
        "tenant" => tenant,
        "ebics" => {
          "protocol" => "H005"
        }
      })
    }
  end

  def with_env(values)
    previous = values.keys.index_with { |key| ENV[key] }
    values.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
