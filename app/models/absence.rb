class Absence < ActiveRecord::Base
  belongs_to :member

  validates :member, :started_on, :ended_on, presence: true
  validate :good_period_range

  scope :past, -> { where('ended_on < ?', Time.now) }
  scope :future, -> { where('started_on > ?', Time.now) }
  scope :current, -> { including_date(Time.zone.today) }
  scope :including_date,
    ->(date) { where('started_on <= ? AND ended_on >= ?', date, date) }
  scope :during_year, ->(year) {
    where(
      'started_on >= ? AND ended_on <= ?',
      Date.new(year).beginning_of_year,
      Date.new(year).end_of_year
    )
  }

  def period
    started_on..ended_on
  end

  def self.ransackable_scopes(auth_object = nil)
    %i(including_date)
  end

  private

  def good_period_range
    if started_on >= ended_on
      errors.add(:started_on, 'doit être avant la fin')
      errors.add(:ended_on, 'doit être après le début')
    end
  end
end
