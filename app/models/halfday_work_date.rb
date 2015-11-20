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

  def participants_limit_reached?(period)
    return unless participants_limit.present?

    HalfdayWork.where(date: date)
      .select { |hw| hw.periods.include?(period) }
      .sum(&:participants_count) >= participants_limit
  end
end
