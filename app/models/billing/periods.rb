# frozen_string_literal: true

module Billing
  module Periods
    def self.build(fiscal_year:, billing_year_division:)
      period_length = 12 / billing_year_division
      min = fiscal_year.beginning_of_year

      billing_year_division.times.map do
        old_min = min
        min += period_length.months
        old_min...min
      end
    end

    def self.last_fy_month(membership)
      end_dates = [ membership.ended_on ]
      if Current.org.billing_ends_on_last_delivery_fy_month?
        last_delivery = membership.deliveries.last
        end_dates << last_delivery.date if last_delivery
      end
      Current.org.fy_month_for(end_dates.min)
    end
  end
end
