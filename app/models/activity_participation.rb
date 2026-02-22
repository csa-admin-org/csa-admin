# frozen_string_literal: true

class ActivityParticipation < ApplicationRecord
  REMINDER_DELAY = 3.days

  include HasState # only partially
  include HasNote
  include HasComment
  include BulkActivityIdsInsert
  include Carpooling
  include Searchable

  searchable :activity_title, :activity_date, priority: 5, date: :activity_date

  # Override search_reindex_scope to use an efficient SQL join
  # since activity_date is a method delegating to the activity association.
  def self.search_reindex_scope
    joins(:activity).where(activities: { date: search_min_date.. })
  end

  attr_reader :activity_ids

  belongs_to :activity
  belongs_to :member
  belongs_to :session, optional: true
  belongs_to :validator, class_name: "Admin", optional: true
  has_many :invoices, as: :entity

  def activity_title
    activity&.titles || {}
  end

  def activity_date
    activity&.date
  end

  validates :activity, presence: true, uniqueness: { scope: :member_id }
  validates :participants_count,
    presence: true,
    numericality: {
      less_than_or_equal_to: :missing_participants_count,
      if: :validate_participants_count?,
      on: :create
    },
    unless: :validated_at?

  after_commit :update_membership_activity_participations_accepted!

  scope :validated, -> { where(state: "validated") }
  scope :rejected, -> { where(state: "rejected") }
  scope :review_not_sent, -> { where(review_sent_at: nil) }
  scope :not_rejected, -> { where.not(state: "rejected") }
  scope :pending, -> { joins(:activity).merge(Activity.past_and_today).where(state: "pending") }
  scope :coming, -> { joins(:activity).merge(Activity.coming) }
  scope :future, -> { joins(:activity).merge(Activity.future) }
  scope :past, -> { joins(:activity).merge(Activity.past) }
  scope :between, ->(range) { joins(:activity).merge(Activity.between(range)) }
  scope :activity_wday, ->(wday) { joins(:activity).merge(Activity.wday(wday)) }
  scope :activity_month, ->(month) { joins(:activity).merge(Activity.month(month)) }
  scope :past_current_year, -> { joins(:activity).merge(Activity.past_current_year) }
  scope :current_year, -> { joins(:activity).merge(Activity.current_year) }
  scope :during_year, ->(year) { joins(:activity).merge(Activity.during_year(year)) }

  delegate :missing_participants_count, to: :activity, allow_nil: true

  def self.ransackable_scopes(_auth_object = nil)
    super + %i[activity_wday activity_month during_year]
  end

  def self.invoice_all_missing(year)
    return unless Current.org.activity_price.positive?

    Membership.during_year(year).each do |membership|
      # Check for trial/trial_only memberships
      next unless membership.activity_participations_missing.positive?

      Billing::MissingActivityParticipationsInvoicerJob.perform_later(membership)
    end
  end

  def future?
    pending? && activity.future?
  end

  def state
    future? ? "future" : super
  end

  %w[validated rejected pending].each do |state|
    define_method "#{state}?" do
      self[:state] == state
    end
  end

  def value
    participants_count
  end

  def destroyable?
    deadline = Current.org.activity_participation_deletion_deadline_in_days || 0
    created_at > 1.day.ago || activity.date > deadline.days.from_now.to_date
  end

  def validate!(validator)
    return unless can_validate?

    update!(
      state: "validated",
      validated_at: Time.current,
      validator: validator,
      rejected_at: nil,
      review_sent_at: nil)
  end

  def can_validate?
    !future? && !validated?
  end

  def reject!(validator)
    return unless can_reject?

    update!(
      state: "rejected",
      rejected_at: Time.current,
      validator: validator,
      validated_at: nil,
      review_sent_at: nil)
  end

  def can_reject?
    !future? && !rejected?
  end

  def note_reply_args
    {
      to: session&.email,
      subject: "#{I18n.t("activities.#{Current.org.activity_i18n_scope}.one")}, #{activity.name}",
      cc: member.emails_array - [ session&.email ].compact
    }
  end

  def can_send_email?
    member.emails?
  end

  def emails
    if session && !session.admin_id?
      [ session.email ]
    else
      member.emails_array
    end
  end

  def reminderable?
    return if latest_reminder_sent_at?

    future? && activity.date <= REMINDER_DELAY.from_now
  end

  private

  def validate_participants_count?
    activity.coming? && missing_participants_count
  end

  def update_membership_activity_participations_accepted!
    member.membership(activity.fy_year)&.update_activity_participations_accepted!
  end
end
