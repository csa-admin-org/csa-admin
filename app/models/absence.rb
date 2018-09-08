class Absence < ActiveRecord::Base
  belongs_to :member

  attr_accessor :admin

  validates :member, :started_on, :ended_on, presence: true
  validates :started_on, :ended_on, date: {
    after_or_equal_to: proc { Absence.min_started_on },
    before: proc { Absence.max_ended_on }
  }, on: :create
  validate :good_period_range

  after_commit :update_absent_baskets!
  after_create_commit :notify_new_absence_to_admins

  scope :past, -> { where('ended_on < ?', Time.current) }
  scope :future, -> { where('started_on > ?', Time.current) }
  scope :present_or_future, -> { where('ended_on > ?', Time.current) }
  scope :current, -> { including_date(Date.current) }
  scope :including_date, ->(date) {
    where('started_on <= ? AND ended_on >= ?', date, date)
  }

  def self.min_started_on
    Date.today.next_week
  end

  def self.max_ended_on
    1.year.from_now.end_of_week
  end

  def period
    started_on..ended_on
  end

  def self.ransackable_scopes(_auth_object = nil)
    %i(including_date)
  end

  private

  def good_period_range
    if started_on >= ended_on
      errors.add(:ended_on, :after_start)
    end
  end

  def update_absent_baskets!
    member.update_absent_baskets!
  end

  def notify_new_absence_to_admins
    Admin.notification('new_absence').where.not(id: admin&.id).find_each do |admin|
      Email.deliver_later(:absence_new, admin, self)
    end
  end
end
