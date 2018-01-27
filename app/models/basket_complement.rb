class BasketComplement < ActiveRecord::Base
  has_and_belongs_to_many :deliveries,
    after_add: :add_subscribed_baskets_complement!,
    after_remove: :remove_subscribed_baskets_complement!

  default_scope { order(:name) }

  def annual_price
    price * Delivery.current_year.count
  end

  def annual_price=(annual_price)
    self.price = annual_price / Delivery.current_year.count.to_f
  end

  def display_name; name end

  private

  def add_subscribed_baskets_complement!(delivery)
    delivery.add_subscribed_baskets_complement!(self)
  end

  def remove_subscribed_baskets_complement!(delivery)
    delivery.remove_subscribed_baskets_complement!(self)
  end
end
