class HalfdayWork < ActiveRecord::Base
  PRICE = 60
  belongs_to :member
  belongs_to :validator, class_name: 'Admin'

  PERIODS = %w[am pm].freeze

  scope :status, ->(status) { send(status) }
  scope :validated, -> { where.not(validated_at: nil) }
  scope :rejected, -> { where.not(rejected_at: nil) }
  scope :pending, -> do
    where('date <= ?', Date.today).where(validated_at: nil, rejected_at: nil)
  end
  scope :coming, -> { where('date > ?', Date.today) }
  scope :coming_for_member, -> { where('date >= ?', Date.today) }
  scope :past, -> do
    where('date < ? AND date >= ?', Date.today, Date.today.beginning_of_year)
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

  after_save :send_notifications

  def status
    if validated_at?
      :validated
    elsif rejected_at?
      :rejected
    elsif date <= Date.today
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
    update(rejected_at: nil, validated_at: Time.now, validator_id: validator.id)
  end

  def reject!(validator)
    return if coming?
    update(rejected_at: Time.now, validated_at: nil, validator_id: validator.id)
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
end
