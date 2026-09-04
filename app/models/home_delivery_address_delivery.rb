# frozen_string_literal: true

class HomeDeliveryAddressDelivery < ApplicationRecord
  belongs_to :home_delivery_address, inverse_of: :home_delivery_address_deliveries
  belongs_to :delivery
  belongs_to :member

  before_validation :copy_member_id

  validates :delivery_id, uniqueness: { scope: :home_delivery_address_id }
  validates :delivery_id, uniqueness: { scope: :member_id }

  private

  def copy_member_id
    self.member_id = home_delivery_address&.member_id
  end
end
