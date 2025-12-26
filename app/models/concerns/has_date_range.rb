# frozen_string_literal: true

# Provides date-range scopes and helpers for models with started_on/ended_on columns.
# Similar to HasDate but for ranges instead of single dates.
#
# Models using this concern must have:
# - started_on (date column)
# - ended_on (date column)
#
# Example:
#   class Absence < ApplicationRecord
#     include HasDateRange
#   end
module HasDateRange
  extend ActiveSupport::Concern

  included do
    validates :started_on, :ended_on, presence: true
    validate :valid_date_range

    scope :past, -> { where(ended_on: ..Date.yesterday) }
    scope :future, -> { where(started_on: Date.tomorrow..) }
    scope :current, -> { including_date(Date.current) }
    scope :present_or_future, -> { where(ended_on: Date.current..) }
    scope :including_date, ->(date) { where(started_on: ..date, ended_on: date..) }
    scope :overlaps, ->(range) { where(started_on: ..range.max, ended_on: range.min..) }
    scope :during_year, ->(year) {
      fy = Current.org.fiscal_year_for(year)
      where(started_on: fy.range).or(where(ended_on: fy.range))
    }
  end

  def date_range
    started_on..ended_on
  end

  def past?
    ended_on < Date.current
  end

  def future?
    started_on > Date.current
  end

  def current?
    started_on <= Date.current && ended_on >= Date.current
  end

  def present_or_future?
    ended_on >= Date.current
  end

  private

  def valid_date_range
    return unless started_on && ended_on && started_on >= ended_on

    errors.add(:started_on, :before_end)
    errors.add(:ended_on, :after_start)
  end
end
