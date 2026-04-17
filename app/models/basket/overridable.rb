# frozen_string_literal: true

module Basket::Overridable
  extend ActiveSupport::Concern

  def sync_basket_override!
    delivery_id, diff = compute_override_diff
    override = BasketOverride.find_or_initialize_by(membership: membership, delivery_id: delivery_id)

    if diff.present?
      override.update!(diff: diff, session: Current.session)
    elsif override.persisted?
      override.destroy!
    end
  end

  private

  def compute_override_diff
    if saved_change_to_delivery_id? && delivery_id_before_last_save.present?
      original_delivery = Delivery.find(delivery_id_before_last_save)
      expected = membership.expected_basket_config(original_delivery)
      diff = BasketOverride.compute_diff(expected, config)
      diff["override_delivery_id"] = delivery_id
      [ original_delivery.id, diff ]
    else
      [ delivery_id, BasketOverride.compute_diff_from_basket(self, membership) ]
    end
  end
end
