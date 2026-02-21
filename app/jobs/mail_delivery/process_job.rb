# frozen_string_literal: true

# Async email delivery for both template and newsletter emails.
#
# Enqueued by MailDelivery::Email's after_create_commit callback.
# Delegates all processing to MailDelivery::Email#process!, which
# handles message building, delivery, suppression, and preview storage.
class MailDelivery
  class ProcessJob < ApplicationJob
    queue_as :low

    def perform(mail_delivery_email)
      mail_delivery_email.process!
    end
  end
end
