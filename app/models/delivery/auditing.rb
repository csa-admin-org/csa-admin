# frozen_string_literal: true

# Handles auditing of delivery changes.
#
# This concern extends the base Auditable functionality to:
# - Track changes to delivery configuration attributes
# - Audit shop_open_for_depot_ids changes (stored as shop_closed_for_depot_ids)
#
# The depot IDs are tracked as shop_open_for_depot_ids (the user-facing representation)
# rather than shop_closed_for_depot_ids (the internal storage format), ensuring the
# audit trail matches the admin interface.
#
module Delivery::Auditing
  extend ActiveSupport::Concern

  # Prepended module to override shop_open_for_depot_ids= and capture state
  # before the original method clears the memoized value.
  module DepotIdsTracking
    def shop_open_for_depot_ids=(ids)
      # Capture current state before super clears the memoized value
      @tracked_shop_open_for_depot_ids ||= shop_open_for_depot_ids.dup
      super
    end
  end

  included do
    prepend DepotIdsTracking

    audited_attributes \
      :date,
      :note,
      :shop_open,
      :basket_size_price_percentage
  end

  private

  def audited_nested_changes
    change = compute_shop_open_for_depot_ids_change
    change ? { "shop_open_for_depot_ids" => change } : {}
  end

  def compute_shop_open_for_depot_ids_change
    return unless @tracked_shop_open_for_depot_ids

    before = @tracked_shop_open_for_depot_ids.sort
    after = shop_open_for_depot_ids.sort

    return if before == after

    [ before, after ]
  end
end
