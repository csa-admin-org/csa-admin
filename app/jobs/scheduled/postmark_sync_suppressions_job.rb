module Scheduled
  class PostmarkSyncSuppressionsJob < BaseJob
    def perform
      EmailSuppression.sync_postmark!(fromdate: 1.week.ago)
    end
  end
end
