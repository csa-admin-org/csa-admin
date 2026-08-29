# frozen_string_literal: true

require "test_helper"

class Support::Ticket::WebhookPayloadTest < ActiveSupport::TestCase
  test "builds the support.ticket.created payload" do
    admin = admins(:super)
    ticket = Support::Ticket.create!(
      priority: :high,
      subject: "Need help",
      content: "Shop checkout is broken",
      context: "https://admin.acme.test/members/42",
      emails: "bob@hey.com, alice@gmail.com",
      admin: admin)

    payload = Support::Ticket::WebhookPayload.new(ticket).as_json

    assert_equal "support.ticket.created", payload.fetch("event")
    assert_equal "acme", payload.fetch("tenant")
    assert_equal ticket.id, payload.dig("ticket", "id")
    assert_equal "Need help", payload.dig("ticket", "subject")
    assert_equal "Shop checkout is broken", payload.dig("ticket", "content")
    assert_equal "https://admin.acme.test/members/42", payload.dig("ticket", "context")
    assert_equal "high", payload.dig("ticket", "priority")
    assert_equal ticket.created_at.iso8601, payload.dig("ticket", "created_at")
    assert_equal({
      "id" => admin.id,
      "name" => admin.name,
      "email" => admin.email,
      "language" => admin.language
    }, payload.fetch("admin"))
    assert_equal Current.org.name, payload.dig("org", "name")
    assert_equal "admin.acme.test", payload.dig("org", "admin_host")
    assert_equal "members.acme.test", payload.dig("org", "members_host")
    assert_equal Current.org.email, payload.dig("org", "email")
    assert_equal Current.org.languages, payload.dig("org", "languages")
    assert_equal Current.org.features.map(&:to_s), payload.dig("org", "features")
    assert_equal [ "alice@gmail.com", "bob@hey.com" ], payload.fetch("cc_emails")
    assert_equal [], payload.fetch("attachment_urls")
    assert_nil payload.dig("app", "revision")
    assert_equal I18n.locale.to_s, payload.dig("app", "locale")
  end

  test "admin is null when the ticket has no admin" do
    ticket = Support::Ticket.create!(priority: :normal, subject: "Test", content: "Test")

    payload = Support::Ticket::WebhookPayload.new(ticket).as_json

    assert_nil payload.fetch("admin")
  end

  test "includes https admin-host blob urls for attachments" do
    ticket = Support::Ticket.create!(priority: :normal, subject: "Test", content: "Test")
    attachment = Attachment.new
    attachment.file.attach(
      io: File.open(file_fixture("logo.png")),
      filename: "screenshot.png")
    ticket.update!(attachments: [ attachment ])

    urls = Support::Ticket::WebhookPayload.new(ticket.reload).as_json.fetch("attachment_urls")

    assert_equal 1, urls.size
    assert_match %r{\Ahttps://admin\.acme\.test/}, urls.first
  end
end
