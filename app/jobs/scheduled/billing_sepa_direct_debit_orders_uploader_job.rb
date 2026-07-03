# frozen_string_literal: true

module Scheduled
  class BillingSEPADirectDebitOrdersUploaderJob < BaseJob
    STUCK_UPLOAD_GRACE = 1.day

    def perform
      return unless Current.org.sepa_configured?
      return unless Current.org.bank_connection?

      delay = Billing::SEPADirectDebit::AUTOMATIC_ORDER_UPLOAD_DELAY
      uploadable_invoices = Invoice
        .sepa
        .open
        .sent
        .where(sent_at: ..delay.ago.end_of_day)
        .where(sepa_direct_debit_order_uploaded_at: nil)

      report_stuck_uploads!(uploadable_invoices, delay)

      uploadable_invoices.find_each do |invoice|
        Billing::SEPADirectDebitOrderUploaderJob.perform_later(invoice)
      end
    end

    private

    def report_stuck_uploads!(uploadable_invoices, delay)
      stuck_invoices = uploadable_invoices.where(sent_at: ..(delay + STUCK_UPLOAD_GRACE).ago.end_of_day)
      return unless stuck_invoices.exists?

      Billing::EBICS::SafeContext.report_unexpected("SEPA direct debit orders stuck before upload",
        context: Billing::EBICS::SafeContext.build(
          connection: Current.org.active_bank_connection,
          invoices_count: stuck_invoices.count,
          invoice_ids: stuck_invoices.limit(20).ids,
          oldest_sent_at: stuck_invoices.minimum(:sent_at)))
    end
  end
end
