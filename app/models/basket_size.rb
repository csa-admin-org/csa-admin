class BasketSize < ActiveRecord::Base
  include TranslatedAttributes

  translated_attributes :name

  has_many :memberships
  has_many :members, through: :memberships

  default_scope { order_by_name }

  validates :acp_shares_number,
    numericality: { greater_than_or_equal_to: 1 },
    allow_nil: true

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
