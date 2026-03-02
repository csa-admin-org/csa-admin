# frozen_string_literal: true

class MailDelivery
  class ProcessJob < ApplicationJob
    queue_as :low

    def perform(mail_delivery_email)
      return unless mail_delivery_email.processing?

      mail_delivery_email.process!
    end
  end
end
