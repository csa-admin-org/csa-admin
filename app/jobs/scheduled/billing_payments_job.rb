module Scheduled
  class BillingPaymentsJob < BaseJob
    def perform
      Billing::PaymentsProcessor.process!
    end
  end
end
