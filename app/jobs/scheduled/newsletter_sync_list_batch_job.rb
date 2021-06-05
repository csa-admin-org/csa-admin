module Scheduled
  class NewsletterSyncListBatchJob < BaseJob
    def perform
      ACP.perform_each do
        NewsletterSyncListJob.perform_later
      end
    end
  end
end
