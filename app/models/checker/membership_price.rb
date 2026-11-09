# frozen_string_literal: true

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
      expected_price = computed_membership_price
      if price != expected_price
        Rails.error.unexpected(
          "Membership price cache error",
          context: mismatch_context(expected_price))
        __getobj__.send(:update_price_and_invoices_amount!)
      end
    end

    private

    def mismatch_context(expected_price)
      {
        membership_id: id,
        price: price,
        expected_price: expected_price,
        baskets_annual_price_change: baskets_annual_price_change,
        basket_sizes_price: basket_sizes_price,
        baskets_price_extra: baskets_price_extra,
        basket_complements_price: basket_complements_price,
        basket_complements_annual_price_change: basket_complements_annual_price_change,
        depots_price: depots_price,
        deliveries_price: deliveries_price,
        activity_participations_annual_price_change: activity_participations_annual_price_change
      }.transform_values { |value| error_context_value(value) }
    end

    # Rails.error context is stored as AppSignal tags. Those tags keep strings,
    # symbols, integers, and booleans. Decimal prices are BigDecimal, so a raw
    # value is omitted from the incident and only integer zeros remain.
    def error_context_value(value)
      return value if value.is_a?(Integer) || value.nil?

      value.to_d.to_s("F")
    end
  end
end
