class HalfdayParticipation < ActiveRecord::Base
  include HalfdayNaming
  include HasState # only partially

  attr_reader :carpooling, :halfday_ids
  delegate :missing_participants_count, to: :halfday, allow_nil: true

  belongs_to :halfday
  belongs_to :member
  belongs_to :validator, class_name: 'Admin', optional: true
  has_many :invoices, as: :object

  scope :validated, -> { where(state: 'validated') }
  scope :rejected, -> { where(state: 'rejected') }
  scope :not_rejected, -> { where.not(state: 'rejected') }
  scope :pending, -> { joins(:halfday).merge(Halfday.past).where(state: 'pending') }
  scope :coming, -> { joins(:halfday).merge(Halfday.coming) }
  scope :past_current_year, -> { joins(:halfday).merge(Halfday.past_current_year) }
  scope :during_year, ->(year) { joins(:halfday).merge(Halfday.during_year(year)) }
  scope :carpooling, -> { where.not(carpooling_phone: nil) }

  before_validation :reset_carpooling_data, on: :create, unless: :carpooling

  with_options on: :create, if: :carpooling do
    validates_plausible_phone :carpooling_phone, country_code: 'CH'
    validates :carpooling_phone, presence: true
    validates :carpooling_city, presence: true
  end
  validates :halfday, presence: true, uniqueness: { scope: :member_id }
  validates :participants_count,
    presence: true,
    numericality: {
      less_than_or_equal_to: :missing_participants_count,
      if: :validate_participants_count?,
      on: :create
    },
    unless: :validated_at?

  after_commit :update_membership_recognized_halfday_works!

  def coming?
    pending? && halfday.date > Date.current
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

  def carpooling=(carpooling)
    @carpooling = carpooling == '1'
  end

  def carpooling?
    carpooling_phone
  end

  def destroyable?
    deadline = Current.acp.halfday_participation_deletion_deadline_in_days
    !deadline || created_at > 1.day.ago || halfday.date > deadline.days.from_now
  end

  def validate!(validator)
    return if coming?
    update!(
      state: 'validated',
      validated_at: Time.current,
      validator: validator,
      rejected_at: nil)
    unless validated_at_previous_change.first
      Email.deliver_later(:halfday_validated, self)
    end
  end

  def reject!(validator)
    return if coming?
    update!(
      state: 'rejected',
      rejected_at: Time.current,
      validator: validator,
      validated_at: nil)
    unless rejected_at_previous_change.first
      Email.deliver_later(:halfday_rejected, self)
    end
  end

  def send_reminder_email
    return unless reminderable?

    Email.deliver_now(:halfday_reminder, self)
    touch(:latest_reminder_sent_at)
  end

  private

  def reset_carpooling_data
    self.carpooling_phone = nil
    self.carpooling_city = nil
  end

  def validate_participants_count?
    coming? && missing_participants_count
  end

  def update_membership_recognized_halfday_works!
    member.membership(halfday.fy_year)&.update_recognized_halfday_works!
  end

  def reminderable?
    return unless coming?

    (halfday.date < 2.weeks.from_now && !latest_reminder_sent_at && created_at < 1.day.ago) ||
      (halfday.date < 3.days.from_now && (!latest_reminder_sent_at || latest_reminder_sent_at < 1.week.ago))
  end
end
