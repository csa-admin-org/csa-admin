module Scheduled
  class ChoresJob < BaseJob
    def perform
      update_baskets_counts!
      review_active_state!
      Checker::MembershipPrice.check_all!
      Checker::DeliveryBasketContentAvgPrices.check_all!
      clear_stale_cart_shop_orders!
    end

    private

    def update_baskets_counts!
      Membership
        .current_year
        .find_each(&:update_baskets_counts!)
    end

    def review_active_state!
      Member
        .includes(:current_or_future_membership, :last_membership)
        .find_each(&:review_active_state!)
    end

    def clear_stale_cart_shop_orders!
      Shop::Order
        .cart
        .includes(:depot, :items, :delivery)
        .find_each do |order|
          order.destroy! if order.stale?
        end
    end
  end
end
