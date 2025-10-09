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
end
