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
      clear_stale_and_empty_cart_shop_orders!
    end

    private

    def clear_stale_and_empty_cart_shop_orders!
      Shop::Order
        .cart
        .find_each do |order|
          if !order.can_member_update? && order.empty?
            order.destroy!
          end
        end
    end
  end
end
