# frozen_string_literal: true

module HasDate
  extend ActiveSupport::Concern

  included do
    scope :between, ->(range) { where(date: range) }
    scope :coming, -> { between(Date.current..) }
    scope :future, -> { between(Date.tomorrow..) }
    scope :past_and_today, -> { between(..Date.current) }
    scope :past, -> { between(...Date.current) }
    scope :wday, ->(wday) { where("strftime('%w', date) = ?", wday.to_s) }
    scope :month, ->(month) { where("strftime('%m', date) = ?", month.to_s.rjust(2, "0")) }
  end

  class_methods do
    def ransackable_scopes(_auth_object = nil)
      super + %i[wday month]
    end
  end

  def coming?
    date.today? || future?
  end

  def future?
    date.future?
  end

  def past?
    date.past?
  end
end
