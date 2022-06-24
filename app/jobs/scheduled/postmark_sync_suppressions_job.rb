module Scheduled
  class PostmarkSyncSuppressionsJob < BaseJob
    retry_on StandardError, attempts: 3

    def perform
      EmailSuppression.sync_postmark!(fromdate: 1.week.ago)
    end
  end
end
