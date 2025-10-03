# frozen_string_literal: true

module Billing
  class SEPADirectDebitOrderUploaderJob < ApplicationJob
    queue_as :low

    def perform(invoice)
      return unless invoice.sepa_direct_debit_order_uploadable?
      return unless invoice.sepa_direct_debit_order_automatic_upload_due?

      invoice.upload_sepa_direct_debit_order
    end
  end
end
