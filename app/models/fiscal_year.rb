class FiscalYear
  def self.current(start_month: 1)
    new(Date.current, start_month: start_month)
  end

  def self.for(date_or_year, start_month: 1)
    case date_or_year
    when Date, DateTime, ActiveSupport::TimeWithZone
      new(date_or_year, start_month: start_month)
    when String, Integer
      new(Date.new(date_or_year.to_i, start_month), start_month: start_month)
    when FiscalYear then date_or_year
    else
      raise ArgumentError, 'invalid date or year'
    end
  end

  def initialize(date, start_month: 1)
    @start_month = start_month
    @date = date
  end

  def beginning_of_year
    @date.beginning_of_year + months_diff
  end

  def end_of_year
    @date.end_of_year + months_diff
  end

  def range
    beginning_of_year..end_of_year
  end

  def include?(date)
    range.cover?(date)
  end

  def to_s
    if range.min.year == range.max.year
      range.min.year.to_s
    else
      [range.min.year, range.max.year].join('-')
    end
  end

  def year
    beginning_of_year.year
  end

  def month(date)
    raise ArgumentError, 'date outside fiscal year' unless range.cover?(date)
    (date.year * 12 + date.month) - (beginning_of_year.year * 12 + beginning_of_year.month) + 1
  end

  def current_quarter_range
    quarter = ((month(Date.current) - 1) / 3) + 1
    min = (beginning_of_year + ((quarter - 1) * 3).months).beginning_of_day
    max = (min + 2.months).end_of_month
    min..max
  end

  private

  def months_diff
    if @date.month < @start_month
      - (13 - @start_month).months
    else
      (@start_month - 1).months
    end
  end
end
