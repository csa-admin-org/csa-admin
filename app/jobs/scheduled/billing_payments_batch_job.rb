module Scheduled
  class BillingPaymentsBatchJob < BaseJob
    def perform
      ACP.perform_each do
        BillingPaymentsJob.perform_later
      end
    end
  end
end
