module Scheduled
  class NewsletterSyncListJob < BaseJob
    def perform
      Newsletter.sync_list
    end
  end
end
