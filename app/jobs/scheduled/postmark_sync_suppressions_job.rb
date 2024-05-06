module Scheduled
  class PostmarkSyncSuppressionsJob < BaseJob
    sidekiq_options retry: false

    def perform
      EmailSuppression.sync_postmark!(fromdate: 1.week.ago)
    end
  end
end
