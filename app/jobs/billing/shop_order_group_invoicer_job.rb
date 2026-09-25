# frozen_string_literal: true

module Billing
  class ShopOrderGroupInvoicerJob < ApplicationJob
    queue_as :low

    def perform
      return unless Current.org.iban?
      return unless Current.org.feature?("shop")

      Shop::OrderGroup.invoice_due!
    end
  end
end
