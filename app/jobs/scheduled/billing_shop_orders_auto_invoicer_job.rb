module Scheduled
  class BillingShopOrdersAutoInvoicerJob < BaseJob
    def perform
      return unless Current.acp.feature?('shop')
      return unless Current.acp.shop_order_automatic_invoicing_delay_in_days

      Shop::Order.pending.find_each do |order|
        Billing::ShopOrderInvoicerJob.perform_later(order)
      end
    end
  end
end
