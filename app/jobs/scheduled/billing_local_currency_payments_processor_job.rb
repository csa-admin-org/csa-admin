# frozen_string_literal: true

module Scheduled
  class BillingLocalCurrencyPaymentsProcessorJob < BaseJob
    def perform
      return unless Current.org.feature?("local_currency")

      payments_data = LocalCurrency::Radis.payments_data
      Billing::PaymentsProcessor.new(payments_data).process!
    end
  end
end
