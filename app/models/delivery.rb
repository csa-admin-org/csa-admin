class Delivery < ActiveRecord::Base
  PER_YEAR = 40

  default_scope { order(:date) }

  has_one :gribouille
  has_many :basket_contents

  scope :current_year, -> {
    where("EXTRACT(YEAR FROM date) = #{Time.zone.today.year}")
  }
  scope :next_year, -> {
    where("EXTRACT(YEAR FROM date) = #{Time.zone.today.year + 1}")
  }

  scope :coming, -> { where('date >= ?', Time.zone.today) }
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
    "Livraison #{date} ##{number}"
  end

  def number
    year_dates.index(date) + 1
  end

  def self.next_coming_date
    coming.first.try(:date)
  end

  def self.years_range
    Delivery.minimum(:date).year..Delivery.maximum(:date).year
  end

  private

  def self.next_date(date)
    if date >= Date.new(date.year, 5, 18) && date <= Date.new(date.year, 12, 21)
      date + 1.week
    else
      date + 2.weeks
    end
  end

  def year_dates
    Rails.cache.fetch "#{date.year}_deliveries_dates" do
      Delivery.between(date.beginning_of_year..date.end_of_year).pluck(:date)
    end
  end
end
