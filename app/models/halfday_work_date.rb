class HalfdayWorkDate < ActiveRecord::Base
  PERIODS = %w[am pm].freeze

  scope :coming, -> { where('date > ?', Time.zone.today) }
  scope :after_next_week, -> { where('date > ?', Time.zone.today.next_week) }
  scope :past, -> { where('date < ?', Time.zone.today) }

  validates :date, :periods, presence: true
  validate :period_must_be_unique_per_date

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

  def start_time(period)
    if date.wednesday?
      case period
      when 'am' then Time.zone.parse('7:00')
      when 'pm' then Time.zone.parse('13:30')
      end
    else
      case period
      when 'am' then Time.zone.parse('8:30')
      when 'pm' then Time.zone.parse('13:30')
      end
    end
  end

  def end_time(period)
    if date.wednesday?
      case period
      when 'am' then Time.zone.parse('10:00')
      when 'pm' then Time.zone.parse('17:30')
      end
    else
      case period
      when 'am' then Time.zone.parse('12:00')
      when 'pm' then Time.zone.parse('17:30')
      end
    end
  end

  def place(period)
    if date.wednesday? && period == 'am'
      'Jardin de la Main'
    else
      'Thielle'
    end
  end

  def place_url(period)
    if date.wednesday? && period == 'am'
      'https://goo.gl/maps/tUQcLu1KkPN2'
    else
      'https://goo.gl/maps/xSxmiYRhKWH2'
    end
  end

  def activity(period)
    if date.wednesday? && period == 'am'
      'Confection des paniers'
    else
      'Aide aux champs'
    end
  end

  def full?
    periods.all? { |p| participants_limit_reached?(p) }
  end

  def am_full?
    participants_limit_reached?('am')
  end

  def pm_full?
    participants_limit_reached?('pm')
  end

  def participants_limit_reached?(period)
    return unless participants_limit.present?
    HalfdayWork.where(date: date)
      .select { |hw| hw.periods.include?(period) }
      .sum(&:participants_count) >= participants_limit
  end

  def self.coming_dates_for_gribouille(member)
    next_week = Time.zone.today.next_week
    coming_dates =
      HalfdayWorkDate.coming.where('date < ?', 3.weeks.from_now.to_date).order(:date)
    coming_dates.each_with_object([]) do |hw_date, dates|
      break dates if dates.size == 8
      halfday_work = member.halfday_works.find_by(date: hw_date.date)
      next unless hw_date.date > next_week || halfday_work

      if halfday_work
        dates << { halfday_work_date: hw_date, halfday_work: halfday_work }
      elsif !hw_date.full?
        dates << { halfday_work_date: hw_date }
      end
      dates
    end
  end

  def period_must_be_unique_per_date
    same_date = HalfdayWorkDate.where(date: date).where.not(id: id)
    existing_periods = same_date.flat_map(&:periods).uniq
    if (existing_periods & periods).present?
      errors.add(:period_am, 'existe déjà') if am? && existing_periods.include?('am')
      errors.add(:period_pm, 'existe déjà') if pm? && existing_periods.include?('pm')
    end
  end
end
