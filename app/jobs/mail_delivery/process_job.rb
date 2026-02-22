# frozen_string_literal: true

class MailDelivery
  class ProcessJob < ApplicationJob
    queue_as :low

    def perform(mail_delivery_email)
      mail_delivery_email.process!
    end
  end
end
