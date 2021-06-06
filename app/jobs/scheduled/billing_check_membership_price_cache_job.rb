module Scheduled
  class BillingCheckMembershipPriceCacheJob < BaseJob
    def perform
      Billing::MembershipPriceCacheChecker.check_all!
    end
  end
end
