class Absence < ActiveRecord::Base
  belongs_to :member

  validates :member, :started_on, :ended_on, presence: true
  validate :good_period_range

  after_commit :update_absent_baskets!

  scope :past, -> { where('ended_on < ?', Time.current) }
  scope :future, -> { where('started_on > ?', Time.current) }
  scope :current, -> { including_date(Date.current) }
  scope :including_date, ->(date) {
    where('started_on <= ? AND ended_on >= ?', date, date)
  }

  def period
    started_on..ended_on
  end

  def self.ransackable_scopes(_auth_object = nil)
    %i(including_date)
  end

  private

  def good_period_range
    if started_on >= ended_on
      errors.add(:started_on, :before_end)
      errors.add(:ended_on, :after_start)
    end
  end

  def update_absent_baskets!
    member.update_absent_baskets!
  end
end
