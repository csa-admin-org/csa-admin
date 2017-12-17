class Basket < ActiveRecord::Base
  has_many :memberships
  has_many :members, through: :memberships

  TYPES = %i[small big]
  SMALL = 'Eveil'
  BIG = 'Abondance'

  def self.small; find_by(name: SMALL) end
  def self.big; find_by(name: BIG) end
  def small?; name == SMALL end
  def big?; name == BIG end

  def display_name
    name
  end

  def price
    annual_price / Delivery::PER_YEAR.to_f
  end
end
