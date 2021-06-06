module Scheduled
  class CheckerMembershipPriceJob < BaseJob
    def perform
      Checker::MembershipPrice.check_all!
    end
  end
end
