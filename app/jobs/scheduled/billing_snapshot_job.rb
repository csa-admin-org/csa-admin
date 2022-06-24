module Scheduled
  class BillingSnapshotJob < BaseJob
    retry_on StandardError, attempts: 5

    def perform
      Billing::Snapshot.create_or_update_current_quarter!
    end
  end
end
