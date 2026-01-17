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

  included do
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
