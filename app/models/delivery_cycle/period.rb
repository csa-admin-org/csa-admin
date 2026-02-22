# frozen_string_literal: true

class DeliveryCycle::Period < ApplicationRecord
  FY_MONTHS = (1..12).to_a.freeze

  belongs_to :delivery_cycle, inverse_of: :periods

  enum :results, {
    all: 0,
    odd: 1,
    even: 2,
    quarter_1: 3,
    quarter_2: 4,
    quarter_3: 5,
    quarter_4: 6,
    all_but_first: 7,
    first_of_each_month: 8,
    last_of_each_month: 9
  }, suffix: true

  validates :from_fy_month, :to_fy_month,
    presence: true,
    inclusion: { in: FY_MONTHS }

  validates :to_fy_month,
    numericality: {
      greater_than_or_equal_to: ->(period) { period.from_fy_month || 1 },
      message: :invalid
    },
    allow_blank: true

  validate :no_overlap_with_other_periods

  def fy_month_range
    from_fy_month..to_fy_month if from_fy_month && to_fy_month
  end

  def filter(deliveries)
    deliveries = Array(deliveries).select { |d|
      fy_month_range.cover?(d.fy_month)
    }
    apply_results(deliveries)
  end

  def apply_results(deliveries)
    case results.to_s
    when "all"
      deliveries
    when "all_but_first"
      deliveries[1..-1] || []
    when "odd"
      deliveries.select.with_index { |_, i| (i + 1).odd? }
    when "even"
      deliveries.select.with_index { |_, i| (i + 1).even? }
    when "quarter_1"
      deliveries.select.with_index { |_, i| i % 4 == 0 }
    when "quarter_2"
      deliveries.select.with_index { |_, i| i % 4 == 1 }
    when "quarter_3"
      deliveries.select.with_index { |_, i| i % 4 == 2 }
    when "quarter_4"
      deliveries.select.with_index { |_, i| i % 4 == 3 }
    when "first_of_each_month"
      deliveries.group_by { |d| d.date.mon }.map { |_, ds| ds.first }
    when "last_of_each_month"
      deliveries.group_by { |d| d.date.mon }.map { |_, ds| ds.last }
    else
      deliveries
    end
  end

  private

  def no_overlap_with_other_periods
    return unless fy_month_range
    return unless delivery_cycle

    # Check in-memory sibling periods (handles nested attributes scenario)
    sibling_periods = delivery_cycle.periods.reject { |p|
      p == self || p.marked_for_destruction?
    }

    overlaps = sibling_periods.any? { |p|
      p.fy_month_range&.overlap?(fy_month_range)
    }

    if overlaps
      errors.add(:from_fy_month, :delivery_cycle_periods_overlap)
      errors.add(:to_fy_month, :delivery_cycle_periods_overlap)
    end
  end
end
