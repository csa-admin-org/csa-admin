# frozen_string_literal: true

class Absence < ApplicationRecord
  include HasDateRange, HasNote, HasComment
  include AdminNotifications

  belongs_to :member
  belongs_to :session, optional: true

  has_many :baskets, dependent: :nullify
  has_many :basket_shifts, dependent: :destroy

  validates :started_on, :ended_on, date: {
    after_or_equal_to: proc { Absence.min_started_on },
    before: proc { Absence.max_ended_on }
  }, unless: :admin

  after_save :clear_conflicting_forced_deliveries!
  after_commit :update_memberships!
  after_commit -> { MailTemplate.deliver(:absence_created, absence: self) }

  def self.min_started_on
    Current.org.absence_notice_period_limit_on
  end

  def self.max_ended_on
    1.year.from_now.end_of_week.to_date
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
