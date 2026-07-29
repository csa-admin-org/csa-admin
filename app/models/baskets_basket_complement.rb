# frozen_string_literal: true

class BasketsBasketComplement < ApplicationRecord
  include HasDescription

  belongs_to :basket, touch: true
  belongs_to :basket_complement
  has_one :delivery, through: :basket

  scope :ordered, -> {
    joins(:basket_complement).merge(BasketComplement.ordered)
  }
  scope :for_delivery, ->(delivery, complement) {
    joins(:basket).where(
      baskets: { delivery_id: delivery.id },
      basket_complement_id: complement.id)
  }

  validates :basket_complement_id, uniqueness: { scope: :basket_id }
  validates :price, numericality: { greater_than_or_equal_to: 0 }, presence: true
  validates :quantity, numericality: { greater_than_or_equal_to: 0 }, presence: true
  validate :basket_delivery_must_be_in_complement_deliveries

  before_validation do
    self.price ||= basket_complement&.price
  end

  class << self
    def handle_deliveries_addition!(delivery, complement)
      basket_ids = []
      baskets_missing_complement(delivery, complement).find_each do |basket|
        create_from_subscription!(basket, complement)
        basket_ids << basket.id
      end
      basket_ids
    end

    def handle_deliveries_removal!(delivery, complement)
      scope = for_delivery(delivery, complement)
      basket_ids = scope.distinct.pluck(:basket_id)
      scope.delete_all
      basket_ids
    end

    private

    def baskets_missing_complement(delivery, complement)
      already = where(basket_complement_id: complement.id).select(:basket_id)

      delivery
        .baskets
        .unscope(:order)
        .joins(membership: :memberships_basket_complements)
        .where(memberships_basket_complements: { basket_complement_id: complement.id })
        .where.not(id: already)
        .includes(membership: :memberships_basket_complements)
    end

    def create_from_subscription!(basket, complement)
      subscription = basket.membership.memberships_basket_complements
        .detect { |mbc| mbc.basket_complement_id == complement.id }

      create!(
        basket: basket,
        basket_complement: complement,
        quantity: subscription.quantity,
        price: subscription.price)
    end
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
