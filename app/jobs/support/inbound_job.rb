# frozen_string_literal: true

# Tenant is taken from the recipient address so the webhook can enqueue
# unrecognized mail without a tenant context. The job then raises.
class Support::InboundJob < ActiveJob::Base
  retry_on ActiveRecord::Deadlocked
  retry_on ActiveRecord::StatementTimeout, wait: 5.seconds, attempts: 3
  retry_on ActiveStorage::FileNotFoundError
  discard_on ActiveJob::DeserializationError

  def perform(payload)
    payload = payload.to_h.deep_stringify_keys
    recipients = [
      payload["ToFull"],
      payload["OriginalRecipient"],
      payload["To"]
    ]
    address = Support::InboundAddress.parse(*recipients)
    raise Support::Inbound::UnrecognizedAddress, recipients unless address&.recognized?
    return if address.demo?

    Tenant.switch(address.tenant) {
      Support::Ticket.ingest_inbound(payload, address)
    }
  end
end
