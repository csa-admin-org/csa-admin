# frozen_string_literal: true

module Scheduled
  class BillingShopOrdersAutoInvoicerJob < BaseJob
    def perform
      return unless Current.org.feature?("shop")
      return unless Current.org.shop_order_automatic_invoicing_delay_in_days

      Shop::Order.pending.find_each do |order|
        Billing::ShopOrderAutoInvoicerJob.perform_later(order)
      end
    end
  end
end
