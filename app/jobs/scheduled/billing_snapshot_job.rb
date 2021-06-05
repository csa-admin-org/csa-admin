module Scheduled
  class BillingSnapshotJob < BaseJob
    def perform
      Billing::Snapshot.create_or_update_current_quarter!
    end
  end
end
