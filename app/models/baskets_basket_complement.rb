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
      return [] unless delivery.id.in?(complement.current_and_future_delivery_ids)

      rows = missing_subscription_rows(delivery, complement)
      return [] if rows.empty?

      bulk_insert_from_subscriptions!(rows, complement)
      rows.map(&:first)
    end

    def handle_deliveries_removal!(delivery, complement)
      scope = for_delivery(delivery, complement)
      basket_ids = scope.distinct.pluck(:basket_id)
      scope.delete_all
      basket_ids
    end

    private

    def missing_subscription_rows(delivery, complement)
      already = where(basket_complement_id: complement.id).select(:basket_id)

      delivery.baskets.unscope(:order)
        .joins(membership: :memberships_basket_complements)
        .where(memberships_basket_complements: { basket_complement_id: complement.id })
        .where.not(id: already)
        .pluck(
          "baskets.id",
          "memberships_basket_complements.quantity",
          "memberships_basket_complements.price")
    end

    def bulk_insert_from_subscriptions!(rows, complement)
      now = Time.current
      insert_all!(rows.map { |basket_id, quantity, price|
        {
          basket_id: basket_id,
          basket_complement_id: complement.id,
          quantity: quantity,
          price: price,
          created_at: now,
          updated_at: now
        }
      })
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
