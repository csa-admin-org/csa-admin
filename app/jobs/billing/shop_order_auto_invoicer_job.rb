# frozen_string_literal: true

module Billing
  class ShopOrderAutoInvoicerJob < ApplicationJob
    queue_as :low

    def perform(order)
      order.auto_invoice!
    end
  end
end
