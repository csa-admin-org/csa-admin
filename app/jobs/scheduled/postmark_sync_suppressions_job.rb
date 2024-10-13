# frozen_string_literal: true

module Scheduled
  class PostmarkSyncSuppressionsJob < BaseJob
    retry_on Exception, wait: :polynomially_longer, attempts: 3

    def perform
      EmailSuppression.sync_postmark!(fromdate: 1.week.ago)
    end
  end
end
