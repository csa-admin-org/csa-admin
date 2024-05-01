module HasDate
  extend ActiveSupport::Concern

  included do
    scope :between, ->(range) { where(date: range) }
    scope :coming, -> { between(Date.current..) }
    scope :future, -> { between(Date.tomorrow..) }
    scope :past_and_today, -> { between(..Date.current) }
    scope :past, -> { between(...Date.current) }
    scope :wday, ->(wday) { where("EXTRACT(DOW FROM date) = ?", wday) }
    scope :month, ->(month) { where("EXTRACT(MONTH FROM date) = ?", month) }
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
