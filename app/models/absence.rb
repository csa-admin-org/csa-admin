# frozen_string_literal: true

class Absence < ApplicationRecord
  include HasDateRange, HasNote, HasComment

  attr_accessor :admin

  belongs_to :member
  belongs_to :session, optional: true

  has_many :baskets, dependent: :nullify
  has_many :basket_shifts, dependent: :destroy

  validates :started_on, :ended_on, date: {
    after_or_equal_to: proc { Absence.min_started_on },
    before: proc { Absence.max_ended_on }
  }, unless: :admin
  validate :within_current_fiscal_year

  after_save :clear_conflicting_forced_deliveries!
  after_commit :update_memberships!
  after_commit -> { MailTemplate.deliver(:absence_created, absence: self) }, on: :create

  def self.min_started_on
    Current.org.absence_notice_period_limit_on
  end

  def self.earliest_start_on
    [ min_started_on, Current.fy_range.min ].max
  end

  def self.max_ended_on
    1.year.from_now.end_of_week.to_date
  end

  def can_update?
    ended_on.present? && ended_on >= Current.fy_range.min
  end

  def can_destroy?
    started_on.present? && started_on >= Current.fy_range.min
  end

  def started_on_locked?
    persisted? && started_on_in_database.present? &&
      started_on_in_database < Current.fy_range.min
  end

  def self.ransackable_scopes(_auth_object = nil)
    super + %i[including_date during_year]
  end

  def note_reply_args
    {
      to: session&.email,
      subject: "#{self.class.model_name.human} #{I18n.l(started_on, format: :medium)} – #{I18n.l(ended_on, format: :medium)}",
      cc: member.emails_array - [ session&.email ].compact
    }
  end

  private

  def within_current_fiscal_year
    return if started_on.blank? || ended_on.blank?

    floor = Current.fy_range.min
    if ended_on_in_database && ended_on_in_database < floor
      errors.add(:base, :past_fiscal_year) if changed?
    elsif started_on_in_database && started_on_in_database < floor
      errors.add(:started_on, :fiscal_year_locked) if started_on_changed?
      if ended_on < floor - 1.day
        errors.add(:ended_on, :on_or_after, date: I18n.l(floor - 1.day))
      end
    elsif started_on < floor
      errors.add(:started_on, :current_fiscal_year)
    end
  end

  def clear_conflicting_forced_deliveries!
    ForcedDelivery
      .joins(:member)
      .where(member: { id: member_id })
      .where(delivery_id: Delivery.between(date_range))
      .delete_all
  end

  def update_memberships!
    min = [ started_on_previously_was, started_on ].compact.min
    max = [ ended_on_previously_was, ended_on ].compact.max
    member.memberships.overlaps(min..max).find_each(&:save!)
  end
end
