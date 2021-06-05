module Scheduled
  class BillingSnapshotBatchJob < BaseJob
    def perform
      ACP.perform_each do
        if Billing::Snapshot.end_of_quarter?
          BillingSnapshotJob.perform_later
        end
      end
    end
  end
end
