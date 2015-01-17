class Basket < ActiveRecord::Base
  has_many :memberships
  has_many :members, through: :memberships

  def display_name
    "#{name} (#{year})"
  end

  def self.current_small
    self.where(year: Date.today.year).order(:annual_price).first
  end

  def self.current_big
    self.where(year: Date.today.year).order(:annual_price).last
  end

  def self.years_range
    years = pluck(:year)
    years.min..years.max
  end
end
