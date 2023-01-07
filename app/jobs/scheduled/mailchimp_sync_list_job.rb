module Scheduled
  class MailchimpSyncListJob < BaseJob
    def perform
      Mailchimp.sync_list
    end
  end
end
