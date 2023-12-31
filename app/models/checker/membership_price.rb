module Checker
  class MembershipPrice < SimpleDelegator
    def self.check_all!
      Membership.current_year.find_each do |m|
        new(m).check!
      end
    end

    def initialize(membership)
      super(membership)
    end

    def check!
      expected_price =
        basket_sizes_price +
        baskets_price_extra +
        baskets_annual_price_change +
        basket_complements_price +
        basket_complements_annual_price_change +
        depots_price +
        activity_participations_annual_price_change
      if price != expected_price
        Sentry.capture_message("Membership price cache error", extra: {
          membership_id: id,
          price: price,
          expected_price: expected_price,
          baskets_annual_price_change: baskets_annual_price_change,
          basket_sizes_price: basket_sizes_price,
          baskets_price_extra: baskets_price_extra,
          basket_complements_price: basket_complements_price,
          basket_complements_annual_price_change: basket_complements_annual_price_change,
          depots_price: depots_price,
          activity_participations_annual_price_change: activity_participations_annual_price_change
        })
        __getobj__.send(:update_price_and_invoices_amount!)
      end
    end
  end
end
