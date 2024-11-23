# frozen_string_literal: true

class ActivityParticipation < ApplicationRecord
  include HasState # only partially
  include HasNote
  include BulkActivityIdsInsert

  attr_accessor :comment
  attr_reader :carpooling, :activity_ids

  delegate :missing_participants_count, to: :activity, allow_nil: true

  belongs_to :activity
  belongs_to :member
  belongs_to :session, optional: true
  belongs_to :validator, class_name: "Admin", optional: true
  has_many :invoices, as: :entity

  scope :validated, -> { where(state: "validated") }
  scope :rejected, -> { where(state: "rejected") }
  scope :review_not_sent, -> { where(review_sent_at: nil) }
  scope :not_rejected, -> { where.not(state: "rejected") }
  scope :pending, -> { joins(:activity).merge(Activity.past_and_today).where(state: "pending") }
  scope :coming, -> { joins(:activity).merge(Activity.coming) }
  scope :future, -> { joins(:activity).merge(Activity.future) }
  scope :between, ->(range) { joins(:activity).merge(Activity.between(range)) }
  scope :activity_wday, ->(wday) { joins(:activity).merge(Activity.wday(wday)) }
  scope :activity_month, ->(month) { joins(:activity).merge(Activity.month(month)) }
  scope :past_current_year, -> { joins(:activity).merge(Activity.past_current_year) }
  scope :current_year, -> { joins(:activity).merge(Activity.current_year) }
  scope :during_year, ->(year) { joins(:activity).merge(Activity.during_year(year)) }
  scope :carpooling, -> { where.not(carpooling_phone: nil) }

  before_validation :reset_carpooling_data, on: :create, unless: :carpooling

  with_options on: :create, if: :carpooling do
    validates_plausible_phone :carpooling_phone, country_code: "CH"
    validates :carpooling_phone, presence: true
    validates :carpooling_city, presence: true
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

  def self.ransackable_scopes(_auth_object = nil)
    super + %i[ activity_wday activity_month during_year ]
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

  def carpooling_participations
    @carpooling_participations ||= self.class
      .where(activity_id: activity_id)
      .where.not(member_id: member_id)
      .carpooling
      .includes(:member)
  end

  def carpooling_phone=(phone)
    super PhonyRails.normalize_number(phone,
      default_country_code: Current.org.country_code)
  end

  def carpooling_phone
    super&.phony_formatted(format: :international)
  end

  def carpooling=(boolean)
    @carpooling = ActiveRecord::Type::Boolean.new.cast(boolean)
  end

  def carpooling?
    carpooling_phone
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

    future? && activity.date <= 3.days.from_now
  end

  private

  def reset_carpooling_data
    self.carpooling_phone = nil
    self.carpooling_city = nil
  end

  def validate_participants_count?
    activity.coming? && missing_participants_count
  end

  def update_membership_activity_participations_accepted!
    member.membership(activity.fy_year)&.update_activity_participations_accepted!
  end
end
