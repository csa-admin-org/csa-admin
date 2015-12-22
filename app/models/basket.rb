class Basket < ActiveRecord::Base
  has_many :memberships
  has_many :members, through: :memberships

  SMALL = 'Eveil'
  BIG = 'Abondance'

  scope :current_year, -> { where(year: Time.zone.today.year) }
  scope :small, -> { where(name: SMALL) }
  scope :big, -> { where(name: BIG) }

  def display_name
    "#{name} (#{year})"
  end

  def price
    annual_price / Delivery::PER_YEAR.to_f
  end

  def small?
    name == SMALL
  end

  def big?
    name == BIG
  end

  def self.current_small
    current_year.small.first
  end

  def self.current_big
    current_year.big.first
  end

  def self.years_range
    years = pluck(:year)
    years.min..years.max
  end
end
