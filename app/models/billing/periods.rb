# frozen_string_literal: true

# Shared billing period utilities used by both Billing::Invoicer and
# Billing::PrevisionalInvoicing.
#
# Centralizes the logic for dividing a fiscal year into billing periods
# and determining the last billable fiscal year month for a membership.
#
module Billing
  module Periods
    # Builds an array of date ranges representing billing periods for the
    # given fiscal year and division.
    #
    #   Billing::Periods.build(fiscal_year: fy, billing_year_division: 4)
    #   # => [Jan1...Apr1, Apr1...Jul1, Jul1...Oct1, Oct1...Jan1]
    #
    def self.build(fiscal_year:, billing_year_division:)
      period_length = 12 / billing_year_division
      min = fiscal_year.beginning_of_year

      billing_year_division.times.map do
        old_min = min
        min += period_length.months
        old_min...min
      end
    end

    # Returns the last billable fiscal year month (1-12) for a membership,
    # respecting the billing_ends_on_last_delivery_fy_month org setting.
    #
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
