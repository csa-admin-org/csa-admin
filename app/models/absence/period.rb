# frozen_string_literal: true

module Absence::Period
  extend ActiveSupport::Concern

  included do
    validates :started_on, :ended_on, presence: true
    validates :started_on, :ended_on, date: {
      after_or_equal_to: proc { Absence.min_started_on },
      before: proc { Absence.max_ended_on }
    }, unless: :admin
    validate :good_period_range

    scope :past, -> { where(ended_on: ..Date.yesterday) }
    scope :future, -> { where(started_on: Date.tomorrow..) }
    scope :present_or_future, -> { where(ended_on: Date.tomorrow..) }
    scope :current, -> { including_date(Date.current) }
    scope :including_date, ->(date) { where(started_on: ..date, ended_on: date..) }
    scope :overlaps, ->(period) { where(started_on: ..period.max, ended_on: period.min..) }
    scope :during_year, ->(year) {
      fy = Current.org.fiscal_year_for(year)
      where(started_on: fy.range).or(where(ended_on: fy.range))
    }
  end

  class_methods do
    def min_started_on
      Current.org.absence_notice_period_limit_on
    end

    def max_ended_on
      1.year.from_now.end_of_week.to_date
    end
  end

  def period
    started_on..ended_on
  end

  def present_or_future?
    ended_on >= Date.current
  end

  private

  def good_period_range
    if started_on && ended_on && started_on >= ended_on
      errors.add(:ended_on, :after_start)
    end
  end
end
