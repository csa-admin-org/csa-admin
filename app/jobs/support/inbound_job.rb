# frozen_string_literal: true

class Support::InboundJob < ApplicationJob
  def perform(payload)
    payload = payload.to_h.deep_stringify_keys
    address = Support::InboundAddress.parse(
      payload["ToFull"],
      payload["OriginalRecipient"],
      payload["To"])
    return unless address&.recognized?
    return if address.demo?

    Support::Ticket.ingest_inbound(payload, address)
  end
end
