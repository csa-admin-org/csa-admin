class BasketSize < ActiveRecord::Base
  has_many :memberships
  has_many :members, through: :memberships

  default_scope { order(:price) }

  scope :billable, -> { where('basket_sizes.price > 0') }

  def annual_price
    price * Delivery.current_year.count
  end

  def annual_price=(annual_price)
    self.price = annual_price / Delivery.current_year.count.to_f
  end

  def display_name; name end
end
