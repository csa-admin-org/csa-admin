# frozen_string_literal: true

module Billing
  class InvoiceOverdueNoticesBatchJob < ApplicationJob
    queue_as :default

    def perform
      Invoice.open.find_each do |invoice|
        InvoiceOverdueNoticeJob.perform_later(invoice)
      end
    end
  end
end
