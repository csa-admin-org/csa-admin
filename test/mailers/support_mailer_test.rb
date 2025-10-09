# frozen_string_literal: true

require "test_helper"

class SupportMailerTest < ActionMailer::TestCase
  test "ticket_email" do
    admin = admins(:external)
    ticket = Support::Ticket.new(
      priority: :high,
      subject: "Test Subject",
      content: "Test content",
      context: "Member 42",
      admin: admin)

    mail = SupportMailer.with(ticket: ticket).ticket_email

    assert_equal [ Admin.ultra.email ], mail.to
    assert_equal "🛟‼️ Test Subject", mail.subject
    assert_equal [ admin.email ], mail.reply_to
    assert_match /Test content/, mail.body.encoded
    assert_match %r{=== Context ===}, mail.body.encoded
    assert_match /Member 42/, mail.body.encoded
  end
end
