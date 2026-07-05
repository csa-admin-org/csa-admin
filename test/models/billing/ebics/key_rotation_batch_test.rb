# frozen_string_literal: true

require "test_helper"

class Billing::EBICS::KeyRotationBatchTest < ActiveSupport::TestCase
  setup do
    BankConnection.delete_all
    org(country_code: "CH")
  end

  test "plan reports provider-matched candidates as ready" do
    create_ebics_connection(name: "RAIFCHEC", capabilities: hcs_capabilities)

    report = Billing::EBICS::KeyRotationBatch.new(provider: "RAIFCHEC").plan

    assert_equal({ "ready" => 1 }, report.fetch("summary"))
    assert_equal "acme", report.dig("results", 0, "tenant")
    assert_equal "ready", report.dig("results", 0, "status")
    assert_equal "candidate", report.dig("results", 0, "state")
    assert_equal "RAIFCHEC", report.dig("results", 0, "bank")
  end

  test "plan can match the connection provider type" do
    create_ebics_connection(name: "RAIFCHEC", capabilities: hcs_capabilities)

    report = Billing::EBICS::KeyRotationBatch.new(provider: "ebics").plan

    assert_equal({ "ready" => 1 }, report.fetch("summary"))
  end

  test "perform treats already rotated connections as no-op" do
    create_ebics_connection(keysize: 4096, capabilities: hcs_capabilities)

    report = Billing::EBICS::KeyRotationBatch.new(tenant_names: [ "acme" ]).perform!

    assert_equal({ "noop" => 1 }, report.fetch("summary"))
    assert_equal "noop", report.dig("results", 0, "status")
    assert_equal "already_at_target", report.dig("results", 0, "state")
    assert_equal 4096, report.dig("results", 0, "participant_min_bits")
  end

  test "perform prepares candidates before validation and rotation" do
    create_ebics_connection(capabilities: hcs_capabilities)
    calls = []
    rotations = [ CandidateRotation.new(calls), PreparedRotation.new(calls) ]
    batch = Billing::EBICS::KeyRotationBatch.new(
      tenant_names: [ "acme" ],
      rotation_factory: ->(tenant:, connection:) { rotations.shift || PreparedRotation.new(calls) })

    report = batch.perform!

    assert_equal %w[readiness prepare validate perform], calls
    assert_equal({ "rotated" => 1 }, report.fetch("summary"))
    assert_equal "rotated", report.dig("results", 0, "status")
  end

  test "perform can verify payments after a successful rotation" do
    create_ebics_connection(capabilities: hcs_capabilities)
    payment_processor = PaymentProcessorSpy.new
    batch = Billing::EBICS::KeyRotationBatch.new(
      tenant_names: [ "acme" ],
      verify_payments: true,
      rotation_factory: ->(tenant:, connection:) { PreparedRotation.new([]) },
      payment_processor: payment_processor)

    report = batch.perform!

    assert payment_processor.called?
    assert_equal({ "rotated" => 1 }, report.fetch("summary"))
    assert_equal "ok", report.dig("results", 0, "payment_verification", "status")
  end

  private

  def create_ebics_connection(name: "HOSTID", keysize: 2048, capabilities: {})
    BankConnection.create!(
      provider: "ebics",
      name: name,
      active: true,
      state: "ready",
      credentials: synthetic_ebics_credentials(secret: secret, keysize: keysize, host_id: name),
      settings: h005_settings,
      capabilities: capabilities)
  end

  def h005_settings
    {
      "protocol" => "H005"
    }
  end

  def hcs_capabilities
    {
      "h005" => {
        "admin_orders" => {
          "HTD" => {
            "status" => "ok",
            "order_infos" => [
              { "admin_order_type" => "HCS" }
            ]
          }
        }
      }
    }
  end

  def secret
    "test-passphrase-value"
  end

  class CandidateRotation
    def initialize(calls)
      @calls = calls
    end

    def readiness
      @calls << "readiness"
      Billing::EBICS::KeyRotationBatchTest.rotation_readiness("candidate", participant_min_bits: 2048)
    end

    def prepare_pending!
      @calls << "prepare"
      Billing::EBICS::KeyRotationBatchTest.rotation_readiness("pending_rotation", participant_min_bits: 2048)
    end
  end

  class PreparedRotation
    def initialize(calls)
      @calls = calls
    end

    def readiness
      Billing::EBICS::KeyRotationBatchTest.rotation_readiness("pending_rotation", participant_min_bits: 2048)
    end

    def request_build_validation
      @calls << "validate"
      {
        "status" => "ok",
        "blockers" => []
      }
    end

    def perform!
      @calls << "perform"
      Billing::EBICS::KeyRotationBatchTest.rotation_readiness("rotated", participant_min_bits: 4096).merge("promoted" => true)
    end
  end

  def self.rotation_readiness(state, participant_min_bits:)
    {
      "tenant" => "acme",
      "state" => state,
      "target_bits" => 4096,
      "protocol" => "H005",
      "blockers" => [],
      "group" => {
        "host_id" => "HOSTID",
        "endpoint_host" => "ebics.example.test"
      },
      "active_keys" => {
        "participant_min_bits" => participant_min_bits,
        "bank_min_bits" => 2048
      },
      "rotation_strategy" => {
        "order_type" => "HCS",
        "status" => "advertised"
      }
    }
  end

  class PaymentProcessorSpy
    def initialize
      @called = false
    end

    def retrieve_and_process!
      @called = true
    end

    def called?
      @called
    end
  end
end
