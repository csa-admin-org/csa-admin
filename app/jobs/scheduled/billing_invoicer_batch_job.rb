module Scheduled
  class BillingInvoicerBatchJob < BaseJob
    def perform
      ACP.perform_each do
        BillingInvoicerJob.perform_later
      end
    end
  end
end
