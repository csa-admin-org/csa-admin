# frozen_string_literal: true

class BasketsBasketComplementsUpdaterJob < ApplicationJob
  queue_as :default
  limits_concurrency key: ->(complement, context) { [ complement.id, context["tenant"] ] }

  def perform(complement, delivery_ids = {})
    complement.transaction do
      Delivery.where(id: delivery_ids[:added]).find_each do |delivery|
        BasketsBasketComplement.handle_deliveries_addition!(delivery, complement)
      end
      Delivery.where(id: delivery_ids[:removed]).find_each do |delivery|
        BasketsBasketComplement.handle_deliveries_removal!(delivery, complement)
      end
    end
  end
end
