# frozen_string_literal: true

module Scheduled
  class MailDeliveriesPurgeJob < BaseJob
    def perform
      MailDelivery.purge_expired!
    end
  end
end
