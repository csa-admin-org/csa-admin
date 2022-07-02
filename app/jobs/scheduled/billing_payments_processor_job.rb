module Scheduled
  class BillingPaymentsProcessorJob < BaseJob
    def perform
      Billing::PaymentsProcessor.process!
    end
  end
end
