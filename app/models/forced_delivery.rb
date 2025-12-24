# frozen_string_literal: true

class ForcedDelivery < ApplicationRecord
  belongs_to :membership, touch: true
  belongs_to :delivery
  has_one :member, through: :membership

  validates :delivery_id,
    uniqueness: { scope: :membership_id },
    inclusion: { in: ->(fd) { fd.membership&.delivery_ids || [] } }

  def basket=(basket)
    self.membership = basket.membership
    self.delivery = basket.delivery
  end
end
