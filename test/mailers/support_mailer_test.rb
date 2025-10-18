# frozen_string_literal: true

require "test_helper"

class SupportMailerTest < ActionMailer::TestCase
  test "ticket_email" do
    admin = admins(:external)
    ticket = Support::Ticket.new(
      priority: :high,
      emails: "bob@hey.com, alice@gmail.com",
      subject: "Test Subject",
      content: "Test content",
      context: "Member 42",
      admin: admin)

    mail = SupportMailer.with(ticket: ticket).ticket_email

    assert_equal [ Admin.ultra.email ], mail.to
    assert_equal [ "alice@gmail.com", "bob@hey.com" ], mail.cc
    assert_equal "🛟‼️ Test Subject", mail.subject
    assert_equal [ admin.email ], mail.reply_to
    assert_includes mail.body.encoded, "Test content"
    assert_includes mail.body.encoded, "Member 42"
  end
end
