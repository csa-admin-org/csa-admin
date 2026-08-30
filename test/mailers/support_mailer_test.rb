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

    with_env("HIGH_PRIORITY_SUPPORT_EMAIL" => "support@csa-admin.org") do
      mail = SupportMailer.with(ticket: ticket).ticket_email

      assert_equal [ Admin.ultra.email, "support@csa-admin.org" ], mail.to
      assert_equal [ "alice@gmail.com", "bob@hey.com" ], mail.cc
      assert_equal "🛟‼️ Test Subject", mail.subject
      assert_equal [ admin.email ], mail.reply_to
      assert_includes mail.body.encoded, "Test content"
      assert_includes mail.body.encoded, "Member 42"
    end
  end

  test "ticket_email does not add high-priority recipient for normal tickets" do
    ticket = Support::Ticket.new(
      priority: :normal,
      emails: "bob@hey.com",
      subject: "Test Subject",
      content: "Test content",
      admin: admins(:external))

    with_env("HIGH_PRIORITY_SUPPORT_EMAIL" => "support@csa-admin.org") do
      mail = SupportMailer.with(ticket: ticket).ticket_email

      assert_equal [ Admin.ultra.email ], mail.to
    end
  end

  test "ticket_email skips blank high-priority recipient" do
    ticket = Support::Ticket.new(
      priority: :high,
      subject: "Test Subject",
      content: "Test content",
      admin: admins(:external))

    with_env("HIGH_PRIORITY_SUPPORT_EMAIL" => nil) do
      mail = SupportMailer.with(ticket: ticket).ticket_email

      assert_equal [ Admin.ultra.email ], mail.to
    end
  end
end
