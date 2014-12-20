class HalfdayWork < ActiveRecord::Base
  belongs_to :member
  belongs_to :validator, class_name: 'Admin'

  PERIODS = %w[am pm].freeze

  scope :status, ->(status) { send(status) }
  scope :validated, -> { where.not(validated_at: nil) }
  scope :rejected, -> { where.not(rejected_at: nil) }
  scope :waiting_validation, -> do
    where('date <= ?', Date.today).where(validated_at: nil, rejected_at: nil)
  end
  scope :coming, -> { where('date > ?', Date.today) }
  scope :past, -> do
    where('date < ? AND date >= ?', Date.today, Date.today.beginning_of_year)
  end

  validates :member_id, :date, presence: true
  validate :date_cannot_be_in_the_past, on: :create
  validate :periods_include_good_value

  def status
    return :validated if validated?
    return :rejected if rejected?
    return :coming if coming?
    return :waiting_validation if waiting_validation?
  end

  def waiting_validation
    !validated? && !rejected && date <= Date.today
  end

  def coming?
    date > Date.today
  end

  def validated?
    validated_at?
  end

  def rejected?
    rejected_at?
  end

  def value
    periods.size * participants_count
  end

  def validate!(validator)
    return if coming?
    update!(rejected_at: nil, validated_at: Time.now, validator: validator)
  end

  def reject!(validator)
    return if coming?
    update!(rejected_at: Time.now, validated_at: nil, validator: validator)
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

  private

  def date_cannot_be_in_the_past
    errors.add(:date, :invalid) if date && date < Date.today
  end

  def periods_include_good_value
    if periods.blank? || !periods.all? { |d| d.in? PERIODS }
      errors.add(:periods, 'Sélectionner au moins un horaire, merci')
    end
  end
end
