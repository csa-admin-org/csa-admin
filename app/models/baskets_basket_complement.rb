class BasketsBasketComplement < ApplicationRecord
  include HasDescription

  belongs_to :basket, touch: true
  belongs_to :basket_complement
  has_one :delivery, through: :basket

  validates :basket_complement_id, uniqueness: { scope: :basket_id }
  validates :price, numericality: { greater_than_or_equal_to: 0 }, presence: true
  validates :quantity, numericality: { greater_than_or_equal_to: 0 }, presence: true
  validate :basket_delivery_must_be_in_complement_deliveries

  before_validation do
    self.price ||= basket_complement&.price
  end

  def self.handle_deliveries_addition!(delivery, complement)
    baskets_with_membership_subscription =
      delivery
        .baskets
        .joins(membership: :memberships_basket_complements)
        .where(memberships_basket_complements: { basket_complement_id: complement.id })
        .includes(membership: :memberships_basket_complements)

    baskets_with_membership_subscription.find_each do |basket|
      unless basket.complement_ids.include?(complement.id)
        membership_subscription =
          basket
            .membership
            .memberships_basket_complements
            .find_by(basket_complement_id: complement.id)
        create!(
          basket_id: basket.id,
          basket_complement_id: complement.id,
          quantity: membership_subscription.quantity,
          price: membership_subscription.price)
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

  def description(public_name: false)
    describe(basket_complement, quantity, public_name: public_name)
  end

  private

  def basket_delivery_must_be_in_complement_deliveries
    unless basket.delivery_id.in?(basket_complement.current_and_future_delivery_ids)
      errors.add(:basket_complement, :exclusion)
    end
  end
end
