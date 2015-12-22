class HalfdayWork < ActiveRecord::Base
  MEMBER_PER_YEAR = 2
  PERIODS = %w[am pm].freeze
  PRICE = 60

  belongs_to :member
  belongs_to :validator, class_name: 'Admin'


  scope :status, ->(status) { send(status) }
  scope :validated, -> { where.not(validated_at: nil) }
  scope :rejected, -> { where.not(rejected_at: nil) }
  scope :pending, -> do
    where('date <= ?', Time.zone.today).where(validated_at: nil, rejected_at: nil)
  end
  scope :coming, -> { where('date > ?', Time.zone.today) }
  scope :coming_for_member, -> { where('date >= ?', Time.zone.today) }
  scope :past, -> do
    where('date < ? AND date >= ?', Time.zone.today, Time.zone.today.beginning_of_year)
  end
  scope :during_year, ->(year) {
    where(
      'date >= ? AND date <= ?',
      Date.new(year).beginning_of_year,
      Date.new(year).end_of_year
    )
  }

  validates :member_id, :date, presence: true
  validate :periods_include_good_value
  validates :date, inclusion: { in: ->(hwc) { HalfdayWorkDate.pluck(:date) } }
  validates :period_am, absence: { if: ->(hwc) { hwc.available_periods.exclude?('am') } }
  validates :period_pm, absence: { if: ->(hwc) { hwc.available_periods.exclude?('pm') } }
  validate :participants_limit_must_not_be_reached

  after_save :send_notifications

  def status
    if validated_at?
      :validated
    elsif rejected_at?
      :rejected
    elsif date <= Time.zone.today
      :pending
    else
      :coming
    end
  end

  %i[validated rejected pending coming].each do |status|
    define_method "#{status}?" do
      self.status == status
    end
  end

  def value
    periods.size * participants_count
  end

  def validate!(validator)
    return if coming?
    update(rejected_at: nil, validated_at: Time.zone.now, validator_id: validator.id)
  end

  def reject!(validator)
    return if coming?
    update(rejected_at: Time.zone.now, validated_at: nil, validator_id: validator.id)
  end

  PERIODS.each do |period|
    define_method "period_#{period}" do
      periods.try(:include?, period)
    end
    define_method "#{period}?" do
      periods.try(:include?, period)
    end

    define_method "period_#{period}=" do |bool|
      periods_will_change!
      self.periods ||= []
      if bool.in? [1, '1']
        self.periods << period
        self.periods.uniq!
      else
        self.periods.delete(period)
      end
    end
  end

  def self.ransackable_scopes(auth_object = nil)
    %i(status)
  end

  def halfday_work_date
    @halfday_work_date ||= HalfdayWorkDate.find_by(date: date)
  end

  def available_periods
    HalfdayWorkDate.find_by(date: date).try(:periods) || PERIODS
  end

  private

  def periods_include_good_value
    if periods.blank? || !periods.all? { |d| d.in? PERIODS }
      errors.add(:periods, 'Sélectionner au moins un horaire, merci')
    end
  end

  def send_notifications
    if validated_at_changed? && validated_at?
      HalfdayWorkMailer.validated(self).deliver_later
    end
    if rejected_at_changed? && rejected_at?
      HalfdayWorkMailer.rejected(self).deliver_later
    end
  end

  private

  def participants_limit_must_not_be_reached
    if period_am || period_pm
      am_limit_reached = halfday_work_date.participants_limit_reached?('am')
      pm_limit_reached = halfday_work_date.participants_limit_reached?('pm')
      if am_limit_reached && pm_limit_reached
        errors.add(:periods, 'La journée est déjà complète, merci!')
      elsif period_am && am_limit_reached
        errors.add(:periods, 'Le matin est déjà complet, merci!')
      elsif period_pm && pm_limit_reached
        errors.add(:periods, "L'après-midi est déjà complète, merci!")
      end
    end
  end
end
