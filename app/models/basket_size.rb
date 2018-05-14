class BasketSize < ActiveRecord::Base
  has_many :memberships
  has_many :members, through: :memberships

  default_scope { order(:price) }

  def annual_price
    (price * deliveries_count).round_to_five_cents
  end

  def annual_price=(annual_price)
    self.price = annual_price / deliveries_count.to_f
  end

  def deliveries_count
    Delivery.current_year.count
  end

  def display_name; name end
end
