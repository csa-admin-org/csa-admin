# frozen_string_literal: true

module Analytics::Pace
  extend ActiveSupport::Concern

  Event = Data.define(:created_at, :weight)

  private

  def pace_chart(id, title, icon)
    return if pace_created_dates.none?

    chart.comparison_line(
      id, pace_title(title), icon, pace_series,
      labels: pace_labels)
  end

  def pace_title(title)
    last_n_title(title, all_pace_years.size)
  end

  def pace_labels
    (0..12).map(&:to_s)
  end

  def all_pace_years
    @all_pace_years ||= series.reject { |year| year.count.zero? }
  end

  def pace_years
    all_pace_years.last(Analytics::PALETTE_SIZE)
  end

  def pace_series
    pace_years.map { |year|
      [ year.fiscal_year.to_s, pace_counts_for(year.fiscal_year) ]
    }
  end

  def pace_counts_for(fiscal_year)
    last_offset = last_pace_offset(fiscal_year)
    counts = Array.new(13, 0)
    pace_events_for(fiscal_year).each do |event|
      created_on = event.created_at.to_date
      offset = pace_offset(created_on, fiscal_year)
      next unless offset

      (offset..12).each { |index| counts[index] += event.weight.to_i }
    end
    (last_offset + 1).upto(12) { |index| counts[index] = nil }
    counts
  end

  def last_pace_offset(fiscal_year)
    today = Date.current
    return 12 if today > fiscal_year.end_of_year
    return 0 if today < fiscal_year.beginning_of_year

    fiscal_year.fy_month(today)
  end

  def pace_offset(created_on, fiscal_year)
    return if created_on < fiscal_year.beginning_of_year
    return 12 if created_on > fiscal_year.end_of_year

    fiscal_year.fy_month(created_on)
  end
end
