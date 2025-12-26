# frozen_string_literal: true

# Handles basket size availability based on calendar week (cweek) ranges.
#
# This allows basket sizes to have a defined delivery period within a fiscal year.
# For example, a basket size might only be delivered from cweek 11 to cweek 45,
# while basket complements continue to be delivered outside this range.
#
# When a basket is created for a delivery date outside the basket size's cweek range,
# the basket's quantity is set to 0 (the member receives only complements).
module BasketSize::Deliverability
  extend ActiveSupport::Concern

  included do
    validates :first_cweek, :last_cweek,
      numericality: {
        greater_than_or_equal_to: 1,
        less_than_or_equal_to: 53,
        only_integer: true,
        allow_nil: true
      }
  end

  def delivered_on?(delivery)
    return true if always_deliverable?

    date_cweek = delivery.date.cweek
    date_cwyear = delivery.date.cwyear

    # Use fiscal year to determine the reference years for cweek comparisons
    # This handles cross-calendar-year fiscal years (e.g., April to March)
    first_cweek_year = delivery.fiscal_year.beginning_of_year.year
    last_cweek_year = delivery.fiscal_year.end_of_year.year

    in_range_after_first = first_cweek.nil? ||
      date_cwyear > first_cweek_year ||
      (date_cwyear == first_cweek_year && date_cweek >= first_cweek)

    in_range_before_last = last_cweek.nil? ||
      date_cwyear < last_cweek_year ||
      (date_cwyear == last_cweek_year && date_cweek <= last_cweek)

    in_range_after_first && in_range_before_last
  end

  def filter_deliveries(deliveries)
    if always_deliverable?
      deliveries
    else
      deliveries.select { |d| delivered_on?(d) }
    end
  end

  def always_deliverable?
    first_cweek.nil? && last_cweek.nil?
  end
end
