class Basket < ActiveRecord::Base
  has_many :memberships
  has_many :members, through: :memberships

  def display_name
    "#{name} (#{year})"
  end

  def self.years_range
    years = pluck(:year)
    years.min..years.max
  end
end
