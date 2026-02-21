# frozen_string_literal: true

module Scheduled
  class PostmarkSyncDeliveriesJob < BaseJob
    def perform
      MailDelivery::Email.sync_stale_from_postmark!
    end
  end
end
