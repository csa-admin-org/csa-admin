# frozen_string_literal: true

class Support::Message::WebhookPayload
  def initialize(message)
    @message = message
  end

  def as_json(*)
    {
      "event" => "support.message.created",
      "tenant" => Tenant.current,
      "ticket_id" => message.ticket_id,
      "message_id" => message.id,
      "author" => message.author,
      "created_at" => message.created_at&.iso8601
    }
  end

  private

  attr_reader :message
end
