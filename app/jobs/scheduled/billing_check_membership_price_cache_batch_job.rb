module Scheduled
  class BillingCheckMembershipPriceCacheBatchJob < BaseJob
    def perform
      ACP.perform_each do
        BillingCheckMembershipPriceCacheJob.perform_later
      end
    end
  end
end
