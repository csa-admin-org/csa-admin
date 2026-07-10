# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class BankConnection::FinalizationNotificationTest < ActiveSupport::TestCase
  setup do
    BankConnection::FinalizationNotification.delete_all
    BankConnection.delete_all
    org(country_code: "CH")
  end

  test "creates one durable notification per finalization event recipient" do
    connection = create_connection

    notifications = BankConnection::FinalizationNotification.create_for_finalization!(
      bank_connection: connection,
      event_id: "event-1")
    duplicate_notifications = BankConnection::FinalizationNotification.create_for_finalization!(
      bank_connection: connection,
      event_id: "event-1")

    assert_equal 2, BankConnection::FinalizationNotification.count
    assert_equal notifications.map(&:id).sort, duplicate_notifications.map(&:id).sort
    assert_equal %w[initiating_admin ultra_admin], notifications.map(&:recipient).sort
  end

  test "duplicate queued jobs skip a delivered recipient" do
    notification = create_notification("initiating_admin")
    mailer = FakeAdminMailer.new

    AdminMailer.stub(:with, ->(**options) { mailer.with(**options) }) do
      BankConnection::FinalizationNotificationJob.new.perform(notification.id)
      BankConnection::FinalizationNotificationJob.new.perform(notification.id)
    end

    assert_equal [ [ admins(:super), notification.bank_connection ] ], mailer.delivered
    assert_predicate notification.reload, :delivered?
    assert notification.delivered_at?
  end

  test "resets a failed delivery without persisting its message" do
    notification = create_notification("ultra_admin")
    mailer = FailingMailer.new

    EBICSOnboardingMailer.stub(:with, ->(**options) { mailer.with(**options) }) do
      assert_raises RuntimeError do
        notification.deliver!
      end
    end

    notification.reload
    assert_predicate notification, :pending?
    assert_equal "RuntimeError", notification.last_error_class
    assert_not notification.attributes.to_json.include?("provider response text")
  end

  test "redispatches an undelivered row after its delivery claim is stale" do
    notification = create_notification("ultra_admin")
    notification.update_columns(state: "delivering", delivery_started_at: 11.minutes.ago)
    dispatched_ids = []

    BankConnection::FinalizationNotificationJob.stub(:perform_later, ->(id) { dispatched_ids << id }) do
      BankConnection::FinalizationNotification.dispatch_pending!
    end

    assert_equal [ notification.id ], dispatched_ids
  end

  private

  def create_notification(recipient)
    BankConnection::FinalizationNotification.create!(
      bank_connection: create_connection,
      event_id: "event-1",
      recipient: recipient)
  end

  def create_connection
    BankConnection.create!(
      provider: "ebics",
      name: "HOSTID",
      active: true,
      state: "ready",
      credentials: synthetic_ebics_credentials(user_id: "PARTICIPANTID", partner_id: "CLIENTID"),
      settings: h005_settings,
      status_details: {
        "onboarding" => {
          "state" => "finalized",
          "initiated_by_admin_id" => admins(:super).id,
          "initiated_by_admin_email" => admins(:super).email
        }
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

  class FakeAdminMailer
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

    def deliver_now
      delivered << [ @admin, @connection ]
    end
  end

  class FailingMailer
    def with(**)
      self
    end

    def finalized_notification_email = self

    def deliver_now
      raise "provider response text"
    end
  end
end
