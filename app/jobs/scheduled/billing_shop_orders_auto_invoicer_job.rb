# frozen_string_literal: true

module Scheduled
  class BillingShopOrdersAutoInvoicerJob < BaseJob
    def perform
      return unless Current.org.iban?
      return unless Current.org.feature?("shop")

      if Current.org.shop_order_automatic_invoicing_delay_in_days
        Shop::Order.pending.without_invoice_period.find_each do |order|
          Billing::ShopOrderAutoInvoicerJob.perform_later(order)
        end
      end

      Billing::ShopOrderGroupInvoicerJob.perform_later
    end
  end
end
