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
    Rake::Task["ebics:key_rotation:readiness"].reenable
    Rake::Task["ebics:key_rotation:prepare"].reenable
    Rake::Task["ebics:key_rotation:validate"].reenable
    Rake::Task["ebics:key_rotation:build"].reenable
    Rake::Task["ebics:key_rotation:submit"].reenable
    Rake::Task["ebics:key_rotation:verify"].reenable
    Rake::Task["ebics:key_rotation:promote"].reenable
    Rake::Task["ebics:key_rotation:perform"].reenable
    Rake::Task["ebics:key_rotation:rollback"].reenable
    Rake::Task["ebics:key_rotation:recover_rollback"].reenable
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
      credentials: ebics_credentials)

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
      credentials: ebics_credentials)

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

  test "key rotation submit verify promote perform rollback and recovery tasks call model with guards" do
    %w[submit verify promote perform rollback recover_rollback].each do |task_name|
      with_env("TENANT" => "ragedevert", "CONFIRM" => nil) do
        Rake::Task["ebics:key_rotation:#{task_name}"].reenable
        assert_raises(SystemExit) { capture_io { Rake::Task["ebics:key_rotation:#{task_name}"].invoke } }
      end
    end

    %w[submit verify promote perform rollback recover_rollback].each do |task_name|
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

  test "key rotation batch prepare and perform require selection and confirmation" do
    %w[prepare perform].each do |task_name|
      with_env("TENANTS" => nil, "PROVIDER" => nil, "ALL" => nil, "CONFIRM" => "true") do
        Rake::Task["ebics:key_rotation:batch:#{task_name}"].reenable
        assert_raises(SystemExit) { capture_io { Rake::Task["ebics:key_rotation:batch:#{task_name}"].invoke } }
      end

      with_env("TENANTS" => "tapatate", "PROVIDER" => nil, "ALL" => nil, "CONFIRM" => nil) do
        Rake::Task["ebics:key_rotation:batch:#{task_name}"].reenable
        assert_raises(SystemExit) { capture_io { Rake::Task["ebics:key_rotation:batch:#{task_name}"].invoke } }
      end
    end
  end

  test "key rotation batch prepare and perform call coordinator when confirmed" do
    { "prepare" => :prepare!, "perform" => :perform! }.each do |task_name, expected_method|
      with_env("TENANTS" => nil, "PROVIDER" => "RAIFCHEC", "ALL" => nil, "VERIFY_PAYMENTS" => "true", "CONFIRM" => "true") do
        Billing::EBICS::KeyRotationBatch.stub(:new, key_rotation_batch_stub(expected_method: expected_method, expected_tenants: [], expected_provider: "RAIFCHEC", expected_all: false, expected_verify_payments: true)) do
          Rake::Task["ebics:key_rotation:batch:#{task_name}"].reenable
          out, = capture_io { Rake::Task["ebics:key_rotation:batch:#{task_name}"].invoke }
          json = JSON.parse(out)

          assert_equal task_name, json.fetch("action")
        end
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
      credentials: ebics_credentials)

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
      credentials: ebics_credentials)

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
      credentials: ebics_credentials)

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
      credentials: ebics_credentials)

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
    {
      keys: "keys",
      secret: "secret",
      url: "https://ebics.example.test",
      host_id: "HOSTID",
      participant_id: "PARTNERID",
      client_id: "USERID"
    }
  end

  def btf_client_stub
    test = self
    ->(_credentials) {
      Object.new.tap do |client|
        client.define_singleton_method(:test_download) do |_operation, from:, to:, acknowledge:|
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
        rotation.define_singleton_method(:rollback!) do
          { "task" => "rollback" }
        end
        rotation.define_singleton_method(:recover_rollback!) do
          { "task" => "recover_rollback" }
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
