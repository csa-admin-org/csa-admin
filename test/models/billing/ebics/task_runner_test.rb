# frozen_string_literal: true

require "test_helper"

class Billing::EBICS::TaskRunnerTest < ActiveSupport::TestCase
  setup do
    BankConnection.delete_all
  end

  test "onboarding initialize passes environment attributes to backend" do
    calls = []
    factory = ->(connection: nil, **_options) {
      assert_nil connection
      Object.new.tap do |fake|
        fake.define_singleton_method(:initialize_connection!) do |**attributes|
          calls << attributes
          { "initialized" => true }
        end
      end
    }

    result = with_existing_tenant do
      Billing::EBICS::Onboarding.stub(:new, factory) do
        Billing::EBICS::TaskRunner.new(env: {
          "TENANT" => "acme",
          "CONFIRM" => "true",
          "URL" => "https://ebics.example.test",
          "HOST_ID" => "HOSTID",
          "PARTNER_ID" => "CLIENTID",
          "USER_ID" => "PARTICIPANTID",
          "NAME" => "Test Bank",
          "KEY_BITS" => "2048"
        }).onboarding_initialize
      end
    end

    assert_equal({ "initialized" => true }, result)
    assert_equal({
      url: "https://ebics.example.test",
      host_id: "HOSTID",
      client_id: "CLIENTID",
      participant_id: "PARTICIPANTID",
      name: "Test Bank",
      target_bits: "2048"
    }, calls.sole)
  end

  test "onboarding letter uses the selected onboarding connection" do
    connection = BankConnection.create!(
      provider: "ebics",
      name: "HOSTID",
      active: false,
      state: "waiting_for_bank",
      health_status: "unknown")
    calls = []
    factory = ->(connection: nil, **_options) {
      Object.new.tap do |fake|
        fake.define_singleton_method(:write_letter!) do |output:, locale:|
          calls << { connection: connection, output: output, locale: locale.to_s }
          { "letter" => { "path" => output, "locale" => locale.to_s } }
        end
      end
    }

    result = with_existing_tenant do
      Billing::EBICS::Onboarding.stub(:new, factory) do
        Billing::EBICS::TaskRunner.new(env: {
          "TENANT" => "acme",
          "OUTPUT" => Rails.root.join("tmp/test-task-runner-letter.pdf").to_s,
          "LOCALE" => "fr"
        }).onboarding_letter
      end
    end

    assert_equal connection, calls.sole.fetch(:connection)
    assert_equal "fr", calls.sole.fetch(:locale)
    assert_equal calls.sole.fetch(:output), result.dig("letter", "path")
  end

  test "key rotation batch perform requires one explicit tenant" do
    error = assert_raises(Billing::EBICS::UnsupportedOperation) do
      Billing::EBICS::TaskRunner.new(env: {
        "TENANTS" => "acme,other",
        "CONFIRM" => "true"
      }).key_rotation_batch_perform
    end

    assert_equal "Use TENANT, not TENANTS, for live batch perform", error.message
  end

  private

  def with_existing_tenant(&block)
    Tenant.stub(:exists?, true) do
      Tenant.stub(:switch, ->(_name, &switch_block) { switch_block.call }, &block)
    end
  end
end
