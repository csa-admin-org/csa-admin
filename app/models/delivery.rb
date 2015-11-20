class Delivery < ActiveRecord::Base
  PER_YEAR = 40

  default_scope { order(:date) }

  scope :coming, -> { where('date >= ?', Time.zone.today)}
  scope :between,
    ->(range) { where('date >= ? AND date <= ?', range.first, range.last) }

  def self.create_all(first_date)
    date = first_date
    PER_YEAR.times do
      create(date: date)
      date = next_date(date)
    end
  end

  def display_name
    "Livraison #{date.year} ##{number}"
  end

  def number
    year_dates.index(date) + 1
  end

  def self.next_coming_date
    coming.first.try(:date)
  end

  private

  def self.next_date(date)
    if date >= Date.new(date.year, 5, 15) && date <= Date.new(date.year, 12, 15)
      date + 1.week
    else
      date + 2.weeks
    end
  end

  def year_dates
    today = Time.zone.today
    Rails.cache.fetch "#{today.year}_deliveries_dates" do
      Delivery.between(today.beginning_of_year..today.end_of_year).pluck(:date)
    end
  end
end
