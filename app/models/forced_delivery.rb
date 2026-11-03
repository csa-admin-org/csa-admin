# frozen_string_literal: true

class ForcedDelivery < ApplicationRecord
  belongs_to :membership, touch: true
  belongs_to :delivery
  has_one :member, through: :membership

  validates :delivery_id,
    uniqueness: { scope: :membership_id },
    inclusion: { in: ->(fd) { fd.membership&.delivery_ids || [] } }

  before_destroy :keep_shifted_delivery

  def basket=(basket)
    self.membership = basket.membership
    self.delivery = basket.delivery
  end

  private

  def keep_shifted_delivery
    return unless membership&.basket_shifts&.exists?(source_delivery_id: delivery_id)

    throw :abort
  end
end
