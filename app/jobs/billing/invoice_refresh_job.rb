# frozen_string_literal: true

module Billing
  class InvoiceRefreshJob < ApplicationJob
    queue_as :critical

    def perform(invoice, expected_updated_at)
      invoice.refresh!(expected_updated_at)
    end
  end
end
