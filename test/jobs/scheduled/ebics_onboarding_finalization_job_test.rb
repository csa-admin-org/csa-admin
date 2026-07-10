# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class Scheduled::EBICSOnboardingFinalizationJobTest < ActiveJob::TestCase
  setup do
    BankConnection.delete_all
    org(country_code: "CH")
  end

  test "does nothing when no EBICS setup is waiting for bank activation" do
    create_connection(state: "initializing")
    admin_mailer = FakeAdminFinalizedMailer.new
    ultra_mailer = FakeFinalizedMailer.new

    AdminMailer.stub(:with, ->(**options) { admin_mailer.with(**options) }) do
      EBICSOnboardingMailer.stub(:with, ->(**options) { ultra_mailer.with(**options) }) do
        Scheduled::EBICSOnboardingFinalizationJob.new.perform
      end
    end

    assert_empty admin_mailer.delivered
    assert_empty ultra_mailer.delivered_connections
  end

  test "skips waiting setup already checked today" do
    travel_to Time.zone.parse("2026-07-07 12:00") do
      create_connection(last_finalization_check_at: "2026-07-07T05:10:00Z")
      called = false

      admin_mailer = FakeAdminFinalizedMailer.new
      ultra_mailer = FakeFinalizedMailer.new

      Billing::EBICS::Onboarding.stub(:new, ->(**_options) { called = true }) do
        AdminMailer.stub(:with, ->(**options) { admin_mailer.with(**options) }) do
          EBICSOnboardingMailer.stub(:with, ->(**options) { ultra_mailer.with(**options) }) do
            Scheduled::EBICSOnboardingFinalizationJob.new.perform
          end
        end
      end

      assert_not called
      assert_empty admin_mailer.delivered
      assert_empty ultra_mailer.delivered_connections
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

  test "checks eligible waiting setup and notifies ultra admin after finalization" do
    connection = create_connection

    admin_mailer = FakeAdminFinalizedMailer.new
    ultra_mailer = FakeFinalizedMailer.new

    Billing::EBICS::Onboarding.stub(:new, ->(connection:, **_options) { FinalizingOnboarding.new(connection) }) do
      AdminMailer.stub(:with, ->(**options) { admin_mailer.with(**options) }) do
        EBICSOnboardingMailer.stub(:with, ->(**options) { ultra_mailer.with(**options) }) do
          Scheduled::EBICSOnboardingFinalizationJob.new.perform
        end
      end
    end

    assert_equal [ [ admins(:super), connection ] ], admin_mailer.delivered
    assert_equal [ connection ], ultra_mailer.delivered_connections
    assert connection.reload.active?
    assert_equal "ready", connection.state
  end

  test "does not notify when finalization check is still waiting for the bank" do
    connection = create_connection

    admin_mailer = FakeAdminFinalizedMailer.new
    ultra_mailer = FakeFinalizedMailer.new

    Billing::EBICS::Onboarding.stub(:new, ->(connection:, **_options) { WaitingOnboarding.new(connection) }) do
      AdminMailer.stub(:with, ->(**options) { admin_mailer.with(**options) }) do
        EBICSOnboardingMailer.stub(:with, ->(**options) { ultra_mailer.with(**options) }) do
          Scheduled::EBICSOnboardingFinalizationJob.new.perform
        end
      end
    end

    assert_empty admin_mailer.delivered
    assert_empty ultra_mailer.delivered_connections
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
      credentials: {
        "url" => "https://ebics.example.test",
        "host_id" => "HOSTID",
        "client_id" => "CLIENTID",
        "participant_id" => "PARTICIPANTID",
        "secret" => "secret",
        "keys" => "keys"
      },
      settings: { "protocol" => "H005" },
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

  class FakeAdminFinalizedMailer
    attr_reader :delivered

    def initialize
      @delivered = []
    end

    def with(admin:, connection:)
      @admin = admin
      @connection = connection
      self
    end

    def ebics_setup_finalized_email = self

    def deliver_later
      delivered << [ @admin, @connection ]
    end
  end

  class FakeFinalizedMailer
    attr_reader :delivered_connections

    def initialize
      @delivered_connections = []
    end

    def with(connection:)
      @connection = connection
      self
    end

    def finalized_notification_email = self

    def deliver_later
      delivered_connections << @connection
    end
  end

  class FinalizingOnboarding
    def initialize(connection)
      @connection = connection
    end

    def check_finalization!
      @connection.update!(
        active: true,
        state: "ready",
        health_status: "healthy",
        status_details: @connection.status_details.deep_merge(
          "onboarding" => {
            "state" => "finalized",
            "last_finalization_check_at" => Time.current.iso8601,
            "last_finalization_status" => "finalized"
          }))
      { "finalized" => true }
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
