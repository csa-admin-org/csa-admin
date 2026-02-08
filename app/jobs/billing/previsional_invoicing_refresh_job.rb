# frozen_string_literal: true

module Billing
  class PrevisionalInvoicingRefreshJob < ApplicationJob
    queue_as :low

    def perform
      Membership.current_and_future_year.find_each do |membership|
        membership.send(:update_price_and_invoices_amount!)
      end
    end
  end
end
