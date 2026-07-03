# frozen_string_literal: true

require "test_helper"
require "json"
require "minitest/mock"
require "rake"

class EbicsRakeTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("ebics:readiness")
    Rake::Task["ebics:readiness"].reenable
    Rake::Task["ebics:capabilities"].reenable
    Rake::Task["ebics:btf_download"].reenable
    BankConnection.delete_all
  end

  test "readiness prints sanitized tenant report as JSON" do
    with_env("TENANT" => "ragedevert", "LIVE_HEV" => "true") do
      Tenant.stub(:exists?, true) do
        Tenant.stub(:switch, ->(_tenant, &block) { block.call }) do
          Billing::EBICS::ReadinessReport.stub(:new, readiness_report_stub) do
            out, = capture_io { Rake::Task["ebics:readiness"].invoke }
            json = JSON.parse(out)

            assert json.fetch("live_hev")
            assert_equal [ { "tenant" => "ragedevert", "ebics" => { "hev" => { "status" => "ok" } } } ], json.fetch("results")
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
    ->(tenant:, live_hev:) {
      assert_equal "ragedevert", tenant
      assert live_hev
      Struct.new(:to_h).new({
        "tenant" => tenant,
        "ebics" => {
          "hev" => {
            "status" => "ok"
          }
        }
      })
    }
  end

  def with_env(values)
    previous = values.keys.index_with { |key| ENV[key] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
