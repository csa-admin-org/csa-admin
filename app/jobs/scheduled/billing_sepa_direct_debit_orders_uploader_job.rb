# frozen_string_literal: true

module Scheduled
  class BillingSEPADirectDebitOrdersUploaderJob < BaseJob
    def perform
      return unless Current.org.sepa_creditor_identifier?
      return unless Current.org.bank_connection?

      delay = Billing::SEPADirectDebit::AUTOMATIC_ORDER_UPLOAD_DELAY
      Invoice
        .sepa
        .open
        .sent
        .where(sent_at: ..delay.ago.end_of_day)
        .where(sepa_direct_debit_order_uploaded_at: nil)
        .find_each do |invoice|
          Billing::SEPADirectDebitOrderUploaderJob.perform_later(invoice)
        end
    end
  end
end
