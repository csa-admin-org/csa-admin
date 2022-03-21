class ActivityParticipation < ApplicationRecord
  include HasState # only partially
  include BulkActivityIdsInsert

  attr_reader :carpooling, :activity_ids
  delegate :missing_participants_count, to: :activity, allow_nil: true

  belongs_to :activity
  belongs_to :member
  belongs_to :session, optional: true
  belongs_to :validator, class_name: 'Admin', optional: true
  has_many :invoices, as: :object

  scope :validated, -> { where(state: 'validated') }
  scope :rejected, -> { where(state: 'rejected') }
  scope :review_not_sent, -> { where(review_sent_at: nil) }
  scope :not_rejected, -> { where.not(state: 'rejected') }
  scope :pending, -> { joins(:activity).merge(Activity.past).where(state: 'pending') }
  scope :coming, -> { joins(:activity).merge(Activity.coming) }
  scope :past_current_year, -> { joins(:activity).merge(Activity.past_current_year) }
  scope :current_year, -> { joins(:activity).merge(Activity.current_year) }
  scope :during_year, ->(year) { joins(:activity).merge(Activity.during_year(year)) }
  scope :carpooling, -> { where.not(carpooling_phone: nil) }

  before_validation :reset_carpooling_data, on: :create, unless: :carpooling

  with_options on: :create, if: :carpooling do
    validates_plausible_phone :carpooling_phone, country_code: 'CH'
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
    super + %i[during_year]
  end

  def coming?
    pending? && activity.date > Date.current
  end

  def state
    coming? ? 'coming' : super
  end

  %w[validated rejected pending].each do |state|
    define_method "#{state}?" do
      self[:state] == state
    end
  end

  def value
    participants_count
  end

  def carpooling_phone=(phone)
    super PhonyRails.normalize_number(phone, default_country_code: 'CH')
  end

  def carpooling=(boolean)
    @carpooling = ActiveRecord::Type::Boolean.new.cast(boolean)
  end

  def carpooling?
    carpooling_phone
  end

  def destroyable?
    deadline = Current.acp.activity_participation_deletion_deadline_in_days
    !deadline || created_at > 1.day.ago || activity.date > deadline.days.from_now
  end

  def validate!(validator)
    return if coming? || validated?

    update!(
      state: 'validated',
      validated_at: Time.current,
      validator: validator,
      rejected_at: nil,
      review_sent_at: nil)
  end

  def reject!(validator)
    return if coming? || rejected?

    update!(
      state: 'rejected',
      rejected_at: Time.current,
      validator: validator,
      validated_at: nil,
      review_sent_at: nil)
  end

  def can_send_email?
    member.emails?
  end

  def reminderable?
    return if latest_reminder_sent_at?

    coming? && activity.date <= 3.days.from_now
  end

  private

  def reset_carpooling_data
    self.carpooling_phone = nil
    self.carpooling_city = nil
  end

  def validate_participants_count?
    coming? && missing_participants_count
  end

  def update_membership_activity_participations_accepted!
    member.membership(activity.fy_year)&.update_activity_participations_accepted!
  end
end
