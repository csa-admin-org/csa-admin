module Scheduled
  class PostmarkSyncSuppressionsJob < BaseJob
    sidekiq_options retry: 3

    def perform
      EmailSuppression.sync_postmark!(fromdate: 1.week.ago)
    end
  end
end
