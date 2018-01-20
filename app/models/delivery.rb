class Delivery < ActiveRecord::Base
  include HasFiscalYearScopes

  default_scope { order(:date) }

  has_one :gribouille
  has_many :baskets
  has_many :basket_contents

  scope :past, -> { where('date < ?', Date.current) }
  scope :coming, -> { where('date >= ?', Date.current) }
  scope :between, ->(range) { where(date: range) }

  def self.create_all(count, first_date)
    date = first_date.next_weekday + 2.days # Wed
    count.times do
      create(date: date)
      date = next_date(date)
    end
  end

  def self.next
    coming.first
  end

  def delivered?
    date < Time.current
  end

  def display_name
    "#{date} ##{number}"
  end

  def number
    year_dates.index(date) + 1
  end

  private

  def self.next_date(date)
    fy_year = Current.acp.fiscal_year_for(date).year
    if date >= Date.new(fy_year, 5, 18) && date <= Date.new(fy_year, 12, 21)
      date + 1.week
    else
      date + 2.weeks
    end
  end

  def year_dates
    Rails.cache.fetch "#{fy_year}_deliveries_dates" do
      Delivery.between(fy_range).pluck(:date)
    end
  end
end
