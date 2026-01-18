# frozen_string_literal: true

# Handles auditing of membership changes.
#
# This concern extends the base Auditable functionality to:
# - Track changes to membership configuration attributes
# - Audit nested memberships_basket_complements changes
# - Record new_config_from metadata to provide context for when changes take effect
#
# The new_config_from date is important because membership edits can specify
# a future date from which the configuration changes should apply, and this
# context is essential for understanding the audit trail.
#
# Note: This concern uses `prepend` to capture the basket complements state before
# the original setter method processes the attributes. This ensures we track
# the before/after state correctly even though accepts_nested_attributes_for
# defines the setter method directly on the class.
#
module Membership::Auditing
  extend ActiveSupport::Concern

  # Attributes that can be applied from a specific date (new_config_from).
  # When these change, we record the new_config_from metadata in the audit.
  CONFIG_ATTRIBUTES = %w[
    basket_size_id basket_size_price basket_price_extra basket_quantity
    depot_id depot_price
    delivery_cycle_id delivery_cycle_price
    absences_included_annually
  ].freeze

  # Prepended module to capture basket complements state before the original
  # method processes the nested attributes. Also overrides audited_nested_changes
  # to ensure it takes precedence over Auditable's default implementation.
  module BasketComplementsTracking
    def memberships_basket_complements_attributes=(*args)
      @tracked_memberships_basket_complements_attributes =
        memberships_basket_complements.map(&:attributes)
      super
    end

    private

    def audited_nested_changes
      change = compute_basket_complements_change
      change ? { "memberships_basket_complements" => change } : {}
    end

    def audit_metadata
      return {} if new_record?
      return {} unless config_attributes_changing?

      { "new_config_from" => new_config_from&.to_s }
    end

    def config_attributes_changing?
      # Check if any config attributes are changing, or if basket complements are changing
      (changes.keys & CONFIG_ATTRIBUTES).any? || compute_basket_complements_change.present?
    end
  end

  included do
    include Auditable
    prepend BasketComplementsTracking

    audited_attributes \
      :member_id,
      :started_on, :ended_on,
      :basket_size_id, :basket_size_price, :basket_price_extra, :basket_quantity,
      :depot_id, :depot_price,
      :delivery_cycle_id, :delivery_cycle_price,
      :baskets_annual_price_change, :basket_complements_annual_price_change,
      :activity_participations_demanded_annually, :activity_participations_annual_price_change,
      :absences_included_annually,
      :billing_year_division,
      :renew, :renewal_annual_fee, :renewed_at, :renewal_opened_at, :renewal_note
  end

  private

  def compute_basket_complements_change
    return unless @tracked_memberships_basket_complements_attributes

    before = serialize_basket_complements(@tracked_memberships_basket_complements_attributes)
    after = serialize_basket_complements(memberships_basket_complements.reject(&:marked_for_destruction?).map(&:attributes))

    return if before == after

    [ before, after ]
  end

  def serialize_basket_complements(complements_attributes)
    complements_attributes
      .reject { |attrs| attrs["_destroy"] == "1" || attrs["_destroy"] == true }
      .sort_by { |attrs| attrs["basket_complement_id"].to_i }
      .map { |attrs|
        {
          "basket_complement_id" => attrs["basket_complement_id"],
          "quantity" => attrs["quantity"],
          "price" => attrs["price"]&.to_f,
          "delivery_cycle_id" => attrs["delivery_cycle_id"]
        }.compact
      }
  end
end
