class BasketSize < ActiveRecord::Base
  has_many :memberships
  has_many :members, through: :memberships

  default_scope { order(:annual_price) }

  def price
    annual_price / Delivery::PER_YEAR.to_f
  end

  def display_name; name end
end
