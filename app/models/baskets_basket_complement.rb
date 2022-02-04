class BasketsBasketComplement < ApplicationRecord
  belongs_to :basket, touch: true
  belongs_to :basket_complement

  validates :basket_complement_id, uniqueness: { scope: :basket_id }
  validates :price, numericality: { greater_than_or_equal_to: 0 }, presence: true
  validates :price, numericality: { equal_to: 0 }, if: :basket_complement_annual_price_type?
  validates :quantity, numericality: { greater_than_or_equal_to: 0 }, presence: true
  validate :basket_delivery_must_be_in_complement_deliveries

  before_validation do
    self.price ||= basket_complement&.delivery_price
  end

  def self.handle_deliveries_addition!(delivery, complement)
    baskets_with_membership_subscription =
      delivery
        .baskets
        .joins(membership: :memberships_basket_complements)
        .where(memberships_basket_complements: { basket_complement_id: complement.id })
        .includes(membership: :memberships_basket_complements)

    baskets_with_membership_subscription.find_each do |basket|
      unless basket.complements.exists?(complement.id)
        membership_subscription =
          basket
            .membership
            .memberships_basket_complements
            .find_by(basket_complement_id: complement.id)
        create!(
          basket: basket,
          basket_complement: complement,
          quantity: membership_subscription.quantity,
          price: membership_subscription.delivery_price)
      end
    end
  end

  def self.handle_deliveries_removal!(delivery, complement)
    all
      .joins(:basket)
      .where(
        baskets: { delivery_id: delivery.id },
        basket_complement_id: complement.id)
      .destroy_all
  end

  def basket_complement_annual_price_type?
    basket_complement&.annual_price_type?
  end

  def description
    case quantity
    when 0 then nil
    when 1 then basket_complement.name
    else "#{quantity} x #{basket_complement.name}"
    end
  end

  private

  def basket_delivery_must_be_in_complement_deliveries
    unless basket.delivery_id.in?(basket_complement.current_and_future_delivery_ids)
      errors.add(:basket_complement, :exclusion)
    end
  end
end
