# frozen_string_literal: true

require "test_helper"

class Support::Message::WebhookPayloadTest < ActiveSupport::TestCase
  test "builds the slim support.message.created payload" do
    ticket = Support::Ticket.create!(
      priority: :high,
      subject: "Need help",
      content: "Shop checkout is broken",
      admin: admins(:super))
    message = ticket.messages.first

    payload = Support::Message::WebhookPayload.new(message).as_json

    assert_equal "support.message.created", payload.fetch("event")
    assert_equal "acme", payload.fetch("tenant")
    assert_equal ticket.id, payload.fetch("ticket_id")
    assert_equal message.id, payload.fetch("message_id")
    assert_equal "admin", payload.fetch("author")
    assert_equal message.created_at.iso8601, payload.fetch("created_at")
    assert_nil payload["ticket"]
    assert_nil payload["attachment_urls"]
  end
end
