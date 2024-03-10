module Billing
  class InvoiceCancellationJob < ApplicationJob
    queue_as :critical

    def perform(invoice, send_email: false)
      invoice.stamp_pdf_as_canceled!
      if send_email
        MailTemplate.deliver_later(:invoice_cancelled, invoice: invoice)
      end
    end
  end
end
