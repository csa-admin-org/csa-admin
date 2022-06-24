module Scheduled
  class BillingPaymentsProcessorJob < BaseJob
    retry_on StandardError, attempts: 10

    def perform
      Billing::PaymentsProcessor.process!
    end
  end
end
