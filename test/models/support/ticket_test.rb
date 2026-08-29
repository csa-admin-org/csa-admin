# frozen_string_literal: true

require "test_helper"

class Support::TicketTest < ActiveSupport::TestCase
  test "subject_decorated" do
    ticket = Support::Ticket.new(
      priority: :normal,
      subject: "Subject")

    assert_equal "🛟 Subject", ticket.subject_decorated

    ticket.priority = :medium
    assert_equal "🛟❗️ Subject", ticket.subject_decorated

    ticket.priority = :high
    assert_equal "🛟‼️ Subject", ticket.subject_decorated
  end

  test "enqueues support email on creation" do
    assert_enqueued_jobs 1, only: ActionMailer::MailDeliveryJob do
      Support::Ticket.create!(priority: :normal, subject: "Test", content: "Test", admin: admins(:external))
    end
  end

  test "enqueues webhook job on creation when URL is set" do
    Support::Ticket.stub(:webhook_url, "https://webhook.example/support") do
      freeze_time do
        assert_enqueued_with(job: Support::TicketNotifyJob, at: 10.seconds.from_now) do
          Support::Ticket.create!(priority: :normal, subject: "Test", content: "Test", admin: admins(:external))
        end
      end
    end
  end

  test "does not enqueue webhook job when URL is blank" do
    Support::Ticket.stub(:webhook_url, nil) do
      assert_no_enqueued_jobs only: Support::TicketNotifyJob do
        Support::Ticket.create!(priority: :normal, subject: "Test", content: "Test", admin: admins(:external))
      end
    end
  end

  test "webhook credentials come from Rails credentials" do
    Rails.application.credentials.stub(:dig, ->(*keys) {
      case keys
      when [ :support_ticket_webhook, :url ] then "https://webhook.example/support"
      when [ :support_ticket_webhook, :authorization ] then "Bearer secret"
      end
    }) do
      assert_equal "https://webhook.example/support", Support::Ticket.webhook_url
      assert_equal "Bearer secret", Support::Ticket.webhook_authorization
    end
  end

  test "webhook authorization prefixes Bearer when missing" do
    Rails.application.credentials.stub(:dig, ->(*keys) {
      "sender-key" if keys == [ :support_ticket_webhook, :authorization ]
    }) do
      assert_equal "Bearer sender-key", Support::Ticket.webhook_authorization
    end
  end

  test "reports high priority ticket" do
    error = ErrorRecorder.new

    with_rails_error(error) do
      Support::Ticket.create!(priority: :high, subject: "Test", content: "Test", admin: admins(:external))
    end

    reported, = error.reports.first
    assert_instance_of Support::Ticket::HighPriorityTicket, reported
    assert_equal "High priority support ticket", reported.message
  end
end
