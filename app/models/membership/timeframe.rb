# frozen_string_literal: true

# Provides temporal scopes and state helpers for memberships.
# Handles date range validation, fiscal year alignment, and time-based queries.
#
# Memberships are constrained to a single fiscal year and have richer temporal
# semantics than simple date ranges (e.g., "started" vs "current" states).
module Membership::Timeframe
  extend ActiveSupport::Concern

  included do
    include HasDateRange

    validate :same_fiscal_year

    scope :started, -> { where(started_on: ..Date.yesterday) }
    scope :current_or_future, -> { current.or(future).order(:started_on) }
    scope :duration_gt, ->(days) { where("julianday(ended_on) - julianday(started_on) > ?", days) }
    scope :current_year, -> { during_year(Current.fy_year) }
    scope :during_year, ->(year) {
      fy = Current.org.fiscal_year_for(year)
      where(started_on: fy.range.min.., ended_on: ..fy.range.max)
    }
    scope :current_and_future_year, -> { where(started_on: Current.fy_range.min..) }
  end

  class_methods do
    def ransackable_scopes(_auth_object = nil)
      super + %i[during_year]
    end
  end

  # Alias for semantic clarity (consistent with Absence::Period)
  def period
    date_range
  end

  def display_period
    [ started_on, ended_on ].map { |date|
      format = Current.org.fiscal_year_start_month == 1 ? :short_no_year : :short
      I18n.l(date, format: format)
    }.join(" – ")
  end

  def fiscal_year
    @fiscal_year ||= Current.org.fiscal_year_for(started_on)
  end

  def fy_year
    fiscal_year.year
  end

  def started?
    started_on <= Date.current
  end

  def current_year?
    fy_year == Current.fy_year
  end

  def current_or_future_year?
    fy_year >= Current.fy_year
  end

  private

  def same_fiscal_year
    return unless ended_on

    if fy_year != Current.org.fiscal_year_for(ended_on).year
      errors.add(:started_on, :same_fiscal_year)
      errors.add(:ended_on, :same_fiscal_year)
    end
  end
end
