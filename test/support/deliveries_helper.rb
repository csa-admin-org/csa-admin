# frozen_string_literal: true

module DeliveriesHelper
  def create_delivery_cycle(attributes = {})
    DeliveryCycle.create!({
      name: "Cycle"
    }.merge(attributes))
  end
end
