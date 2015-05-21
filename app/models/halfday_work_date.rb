class HalfdayWorkDate < ActiveRecord::Base
  PERIODS = %w[am pm].freeze

  scope :coming, -> { where('date > ?', Date.today) }
  scope :after_next_week, -> { where('date > ?', Date.today.next_week) }
  scope :past, -> { where('date < ?', Date.today) }

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
end
