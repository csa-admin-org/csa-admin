# frozen_string_literal: true

require "test_helper"

class Scheduled::EBICSOnboardingFinalizationJobTest < ActiveJob::TestCase
  setup do
    BankConnection::FinalizationNotification.delete_all
    BankConnection.delete_all
    org(country_code: "CH")
  end

  test "does nothing when no EBICS setup is waiting for bank activation" do
    create_connection(state: "initializing")

    assert_no_difference -> { BankConnection::FinalizationNotification.count } do
      Scheduled::EBICSOnboardingFinalizationJob.new.perform
    end
  end

  test "delegates the daily finalization gate to onboarding" do
    travel_to Time.zone.parse("2026-07-07 12:00") do
      expected_connection = create_connection(last_finalization_check_at: "2026-07-07T05:10:00Z")
      onboarding = CheckingOnboarding.new

      Billing::EBICS::Onboarding.stub(:new, ->(connection:, **_options) {
        assert_equal expected_connection, connection
        onboarding
      }) do
        Scheduled::EBICSOnboardingFinalizationJob.new.perform
      end

      assert_equal 1, onboarding.checks
    end
  end

  test "skips waiting setup before HIA submission" do
    create_connection(hia_submitted_at: nil)
    called = false

    Billing::EBICS::Onboarding.stub(:new, ->(**_options) { called = true }) do
      Scheduled::EBICSOnboardingFinalizationJob.new.perform
    end

    assert_not called
  end

  test "checks eligible waiting setup and creates one durable notification per recipient" do
    connection = create_connection

    Billing::EBICS::Onboarding.stub(:new, ->(connection:, **_options) { FinalizingOnboarding.new(connection) }) do
      assert_difference -> { BankConnection::FinalizationNotification.count }, 2 do
        Scheduled::EBICSOnboardingFinalizationJob.new.perform
      end
    end

    notifications = BankConnection::FinalizationNotification.order(:recipient)
    assert connection.reload.active?
    assert_equal "ready", connection.state
    assert_equal %w[initiating_admin ultra_admin], notifications.pluck(:recipient)
    assert_equal 1, notifications.pluck(:event_id).uniq.size
    assert notifications.all?(&:pending?)
  end

  test "does not create notifications when finalization remains waiting for the bank" do
    connection = create_connection

    Billing::EBICS::Onboarding.stub(:new, ->(connection:, **_options) { WaitingOnboarding.new(connection) }) do
      assert_no_difference -> { BankConnection::FinalizationNotification.count } do
        Scheduled::EBICSOnboardingFinalizationJob.new.perform
      end
    end

    assert_not connection.reload.active?
    assert_equal "waiting_for_bank", connection.state
  end

  private

  def create_connection(state: "waiting_for_bank", last_finalization_check_at: nil, hia_submitted_at: "2026-07-07T10:02:00Z")
    BankConnection.create!(
      provider: "ebics",
      name: "HOSTID",
      active: false,
      state: state,
      health_status: "unknown",
      credentials: synthetic_ebics_credentials(user_id: "PARTICIPANTID", partner_id: "CLIENTID"),
      settings: h005_settings,
      status_details: {
        "onboarding" => {
          "state" => state,
          "target_bits" => 4096,
          "initiated_by_admin_id" => admins(:super).id,
          "initiated_by_admin_email" => admins(:super).email,
          "ini_submitted_at" => "2026-07-07T10:01:00Z",
          "hia_submitted_at" => hia_submitted_at,
          "last_finalization_check_at" => last_finalization_check_at
        }.compact
      })
  end

  def h005_settings
    {
      "protocol" => "H005",
      "downloads" => {
        "payments" => {
          "mode" => "btf",
          "btf" => Billing::EBICS::Btf::Presets.camt054(service_name: "REP", scope: "CH", version: "04")
        }
      }
    }
  end

  class FinalizingOnboarding
    def initialize(connection)
      @connection = connection
    end

    def check_finalization!
      event_id = "finalization-event"
      @connection.update!(
        active: true,
        state: "ready",
        health_status: "healthy",
        status_details: @connection.status_details.deep_merge(
          "onboarding" => {
            "state" => "finalized",
            "last_finalization_check_at" => Time.current.iso8601,
            "last_finalization_status" => "finalized",
            "finalization_notification_event_id" => event_id
          }))
      BankConnection::FinalizationNotification.create_for_finalization!(
        bank_connection: @connection,
        event_id: event_id)
      { "finalized" => true }
    end
  end

  class CheckingOnboarding
    attr_reader :checks

    def initialize
      @checks = 0
    end

    def check_finalization!
      @checks += 1
    end
  end

  class WaitingOnboarding
    def initialize(connection)
      @connection = connection
    end

    def check_finalization!
      @connection.update!(status_details: @connection.status_details.deep_merge(
        "onboarding" => {
          "last_finalization_check_at" => Time.current.iso8601,
          "last_finalization_status" => "not_ready"
        }))
      { "finalized" => false }
    end
  end
end
