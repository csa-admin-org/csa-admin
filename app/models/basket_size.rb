class BasketSize < ActiveRecord::Base
  has_many :memberships
  has_many :members, through: :memberships

  default_scope { order(:price) }

  def annual_price
    (price * Delivery.current_year.count).round_to_five_cents
  end

  def annual_price=(annual_price)
    self.price = annual_price / Delivery.current_year.count.to_f
  end

  def display_name; name end
end
