class HalfdayParticipation < ActiveRecord::Base
  include HalfdayNaming

  attr_reader :carpooling, :halfday_ids
  delegate :missing_participants_count, to: :halfday

  belongs_to :halfday
  belongs_to :member
  belongs_to :validator, class_name: 'Admin', optional: true

  scope :validated, -> { where(state: 'validated') }
  scope :rejected, -> { where(state: 'rejected') }
  scope :pending, -> { joins(:halfday).merge(Halfday.past).where(state: 'pending') }
  scope :coming, -> { joins(:halfday).merge(Halfday.coming) }
  scope :past_current_year, -> { joins(:halfday).merge(Halfday.past_current_year) }
  scope :during_year, ->(year) { joins(:halfday).merge(Halfday.during_year(year)) }
  scope :carpooling, ->(date) {
    joins(:halfday).where(halfdays: { date: date }).where.not(carpooling_phone: nil)
  }

  validates :halfday, presence: true, uniqueness: { scope: :member_id }
  validates :participants_count,
    presence: true,
    numericality: {
      less_than_or_equal_to: :missing_participants_count,
      if: :missing_participants_count
    },
    unless: :validated_at?

  before_create :set_carpooling_phone
  after_update :send_notifications
  after_save :update_membership_validated_halfday_works

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

  def validate!(validator)
    return if coming?
    update(
      state: 'validated',
      validated_at: Time.current,
      validator: validator,
      rejected_at: nil)
  end

  def reject!(validator)
    return if coming?
    update(
      state: 'rejected',
      rejected_at: Time.current,
      validator: validator,
      validated_at: nil)
  end

  def self.send_coming_mails
    all.joins(:halfday).where(halfdays: { date: 2.days.from_now }).each do |hp|
      begin
        HalfdayMailer.coming(hp).deliver_now
      rescue => ex
        ExceptionNotifier.notify_exception(ex,
          data: { emails: hp.member.emails, member: hp.member })
      end
    end
  end

  private

  def set_carpooling_phone
    if @carpooling
      if carpooling_phone.blank?
        self.carpooling_phone = member.phones_array.first
      end
    else
      self.carpooling_phone = nil
    end
  end

  def update_membership_validated_halfday_works
    membership = member.memberships.during_year(halfday.fy_year).first
    membership&.update_validated_halfday_works!
  end

  def send_notifications
    if saved_change_to_validated_at? && validated_at?
      HalfdayMailer.validated(self).deliver_now
    end
    if saved_change_to_rejected_at? && rejected_at?
      HalfdayMailer.rejected(self).deliver_now
    end
  rescue => ex
    ExceptionNotifier.notify_exception(ex,
      data: { emails: member.emails, member: member })
  end
end
