module Scheduled
  class NewsletterSyncListJob < BaseJob
    retry_on StandardError, attempts: 10

    def perform
      Newsletter.sync_list
    end
  end
end
