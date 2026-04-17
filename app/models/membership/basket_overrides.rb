# frozen_string_literal: true

# Handles BasketOverride orchestration for a membership.
#
# BasketOverrides are delivery-keyed (membership + delivery), so they survive
# basket destruction during membership config changes.
#
# When baskets are destroyed and recreated within a range (e.g. basket_size or
# depot change via `sync_baskets_with_config_change!`), overrides must be
# reapplied after recreation, and any orphaned overrides (whose deliveries are
# no longer covered by the membership) must be cleaned up.
#
module Membership::BasketOverrides
  extend ActiveSupport::Concern

  included do
    has_many :basket_overrides, dependent: :destroy
  end

  # Returns the canonical basket config the membership expects for a given
  # delivery, used to compute and compare BasketOverride diffs.
  def expected_basket_config(delivery)
    did, dprice = depot_for(delivery)
    expected_complements = memberships_basket_complements
      .includes(:delivery_cycle)
      .select { |mbc|
        delivery.basket_complement_ids.include?(mbc.basket_complement_id) &&
          (!mbc.delivery_cycle || mbc.delivery_cycle.include_delivery?(delivery))
      }
      .map { |mbc|
        { "basket_complement_id" => mbc.basket_complement_id, "quantity" => mbc.quantity, "price" => mbc.price.to_f }
      }
      .sort_by { |c| c["basket_complement_id"] }

    {
      "basket_size_id" => basket_size_id,
      "basket_size_price" => basket_price_for(delivery).to_f,
      "price_extra" => basket_price_extra.to_f,
      "quantity" => basket_quantity,
      "depot_id" => did,
      "depot_price" => dprice.to_f,
      "delivery_cycle_price" => delivery_cycle_price.to_f,
      "complements" => expected_complements
    }
  end

  private

  def reapply_basket_overrides!(range)
    delivery_ids_in_range = baskets.between(range).pluck(:delivery_id).to_set
    basket_overrides.each do |override|
      # Include swaps where either the source or the target delivery landed in
      # the recreated range, otherwise the swap is silently dropped.
      swap_target_in_range =
        override.delivery_swap? && delivery_ids_in_range.include?(override.diff["override_delivery_id"])
      next unless delivery_ids_in_range.include?(override.delivery_id) || swap_target_in_range

      # For swaps where only the target side is in range, the original basket
      # was already moved to the target delivery and has now been destroyed by
      # the config sync. Fall back to the basket recreated at the target.
      basket =
        baskets.find_by(delivery_id: override.delivery_id) ||
          (override.delivery_swap? && baskets.find_by(delivery_id: override.diff["override_delivery_id"]))
      next unless basket

      override.apply_to!(basket)
    end
  end

  def cleanup_orphaned_overrides!
    valid_delivery_ids = baskets.pluck(:delivery_id).to_set
    orphaned_ids = basket_overrides.select { |override|
      next false if valid_delivery_ids.include?(override.delivery_id)
      next false if override.delivery_swap? && valid_delivery_ids.include?(override.diff["override_delivery_id"])
      true
    }.map(&:id)
    BasketOverride.where(id: orphaned_ids).delete_all if orphaned_ids.any?
  end
end
