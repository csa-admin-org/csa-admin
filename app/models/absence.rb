class Absence < ApplicationRecord
  include HasNote

  attr_accessor :admin, :comment

  belongs_to :member
  belongs_to :session, optional: true
  has_many :baskets

  validates :member, :started_on, :ended_on, presence: true
  validates :started_on, :ended_on, date: {
    after_or_equal_to: proc { Absence.min_started_on },
    before: proc { Absence.max_ended_on }
  }, unless: :admin
  validate :good_period_range

  after_create_commit :notify_admins!
  after_commit :update_memberships!

  scope :past, -> { where("ended_on < ?", Time.current) }
  scope :future, -> { where("started_on > ?", Time.current) }
  scope :present_or_future, -> { where("ended_on > ?", Time.current) }
  scope :current, -> { including_date(Date.current) }
  scope :including_date, ->(date) {
    where("started_on <= ? AND ended_on >= ?", date, date)
  }
  scope :during_year, ->(year) {
    fy = Current.acp.fiscal_year_for(year)
    where(started_on: fy.range).or(where(ended_on: fy.range))
  }
  scope :overlaps, ->(period) {
    where("(started_on, ended_on) OVERLAPS (?, ?)", period.min, period.max)
  }

  def self.min_started_on
    Current.acp.absence_notice_period_in_days.days.from_now.beginning_of_day.to_date
  end

  def self.max_ended_on
    1.year.from_now.end_of_week.to_date
  end

  def period
    started_on..ended_on
  end

  def self.ransackable_scopes(_auth_object = nil)
    super + %i[including_date during_year]
  end

  private

  def good_period_range
    if started_on && ended_on && started_on >= ended_on
      errors.add(:ended_on, :after_start)
    end
  end

  def update_memberships!
    min = [started_on_previously_was, started_on].compact.min
    max = [ended_on_previously_was, ended_on].compact.max
    member.memberships.overlaps(min..max).find_each(&:save!)
  end

  def notify_admins!
    attrs = {
      absence: self,
      member: member,
      skip: admin
    }
    Admin.notify!(:new_absence, **attrs)
    Admin.notify!(:new_absence_with_note, **attrs) if note?
  end
end
