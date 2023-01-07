module Scheduled
  class MailchimpSyncListJob < BaseJob
    def perform
      MailChimp.sync_list
    end
  end
end
