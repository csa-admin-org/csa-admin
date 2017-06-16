class HalfdayParticipation < ActiveRecord::Base
  MEMBER_PER_YEAR = 2
  PRICE = 60

  attr_reader :carpooling, :halfday_ids

  belongs_to :halfday
  belongs_to :member
  belongs_to :validator, class_name: 'Admin'

  scope :validated, -> { where(state: 'validated') }
  scope :rejected, -> { where(state: 'rejected') }
  scope :pending, -> do
    joins(:halfday).where('halfdays.date <= ?', Time.zone.today).where(state: 'pending')
  end
  scope :coming, -> { joins(:halfday).where('halfdays.date > ?', Time.zone.today) }
  scope :coming_for_member, -> { joins(:halfday).where('halfdays.date >= ?', Time.zone.today) }
  scope :past, -> do
    joins(:halfday).where(
      'halfdays.date < ? AND halfdays.date >= ?',
      Time.zone.today,
      Time.zone.today.beginning_of_year)
  end
  scope :during_year, ->(year) {
    joins(:halfday).where(
      'halfdays.date >= ? AND halfdays.date <= ?',
      Date.new(year).beginning_of_year,
      Date.new(year).end_of_year)
  }
  scope :carpooling, ->(date) {
    joins(:halfday).where(halfdays: { date: date }).where.not(carpooling_phone: nil)
  }

  validates :halfday, presence: true, uniqueness: { scope: :member_id }
  validate :participants_limit_must_not_be_reached, unless: :validated_at?

  before_create :set_carpooling_phone
  after_update :send_notifications

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
      HalfdayMailer.coming(hp).deliver_now
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

  def send_notifications
    if saved_change_to_validated_at? && validated_at?
      HalfdayMailer.validated(self).deliver_now
    end
    if saved_change_to_rejected_at? && rejected_at?
      HalfdayMailer.rejected(self).deliver_now
    end
  end

  def participants_limit_must_not_be_reached
    if halfday&.full?
      errors.add(:halfday, 'La demi-journée est déjà complète, merci!')
    end
  end
end
