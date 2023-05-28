module Scheduled
  class DailyJob < BaseJob
    def perform
      Membership
        .current_year
        .find_each(&:update_baskets_counts!)
      Member
        .includes(:current_or_future_membership, :last_membership)
        .each(&:review_active_state!)
      Checker::MembershipPrice.check_all!
      Checker::DeliveryBasketContentAvgPrices.check_all!
    end
  end
end
