# frozen_string_literal: true

class BasketsBasketComplementsUpdaterJob < ApplicationJob
  queue_as :default
  limits_concurrency key: ->(complement, delivery_ids, context) { [ complement.id, context["tenant"] ] }

  def perform(complement, delivery_ids = {})
    ApplicationRecord.transaction do
      basket_ids = mutate_without_touching(complement, delivery_ids)
      refresh_affected!(basket_ids)
    end
  end

  private

  def mutate_without_touching(complement, delivery_ids)
    basket_ids = []

    ActiveRecord::Base.no_touching do
      Delivery.where(id: delivery_ids[:added]).find_each do |delivery|
        basket_ids.concat BasketsBasketComplement.handle_deliveries_addition!(delivery, complement)
      end
      Delivery.where(id: delivery_ids[:removed]).find_each do |delivery|
        basket_ids.concat BasketsBasketComplement.handle_deliveries_removal!(delivery, complement)
      end
    end

    basket_ids.uniq
  end

  def refresh_affected!(basket_ids)
    return if basket_ids.empty?

    scope = Basket.unscoped.where(id: basket_ids)
    membership_ids = scope.distinct.pluck(:membership_id)

    scope.includes(:baskets_basket_complements, :membership)
      .find_each(&:write_calculated_price_extra!)
    Membership.where(id: membership_ids).find_each(&:refresh_after_complements_change!)
  end
end
