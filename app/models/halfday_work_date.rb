class HalfdayWorkDate < ActiveRecord::Base
  PERIODS = %w[am pm].freeze

  scope :coming, -> { where('date > ?', Time.zone.today) }
  scope :after_next_week, -> { where('date > ?', Time.zone.today.next_week) }
  scope :past, -> { where('date < ?', Time.zone.today) }

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

  def full?
    periods.all? { |p| participants_limit_reached?(p) }
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
      next unless hw_date.date >= next_week || halfday_work

      if halfday_work
        dates << { halfday_work_date: hw_date, halfday_work: halfday_work }
      elsif !hw_date.full?
        dates << { halfday_work_date: hw_date }
      end
      dates
    end
  end
end
