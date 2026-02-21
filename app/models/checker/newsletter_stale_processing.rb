# frozen_string_literal: true

module Checker
  class NewsletterStaleProcessing < SimpleDelegator
    def self.check_all!
      MailDelivery::Email.stale
        .joins(:mail_delivery)
        .merge(MailDelivery.newsletters)
        .select(Arel.sql("json_extract(mail_deliveries.mailable_ids, '$[0]') AS newsletter_id"))
        .distinct
        .pluck(Arel.sql("json_extract(mail_deliveries.mailable_ids, '$[0]')"))
        .each do |newsletter_id|
          newsletter = Newsletter.find(newsletter_id)
          new(newsletter).check!
        end
    end

    def initialize(newsletter)
      super(newsletter)
    end

    def check!
      stale_count = mail_delivery_emails.merge(MailDelivery::Email.stale).count

      Rails.error.unexpected("Newsletter stale delivery processing", context: {
        newsletter_id: id,
        pending_deliveries: stale_count
      })
    end
  end
end
