module Billing
  class InvoiceProcessorJob < ApplicationJob
    queue_as :critical

    def perform(invoice, send_email: false)
      invoice.process!(send_email: send_email)
    end
  end
end
