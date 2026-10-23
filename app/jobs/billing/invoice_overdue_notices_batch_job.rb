# frozen_string_literal: true

module Billing
  class InvoiceOverdueNoticesBatchJob < ApplicationJob
    queue_as :default

    def perform
      Invoice.open.find_each.with_index do |invoice, index|
        InvoiceOverdueNotice.deliver_later(invoice, wait: index.seconds)
      end
    end
  end
end
