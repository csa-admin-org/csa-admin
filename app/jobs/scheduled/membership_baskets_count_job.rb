module Scheduled
  class MembershipBasketsCountJob < BaseJob
    def perform
      Membership.current_year.find_each(&:update_baskets_counts!)
    end
  end
end
