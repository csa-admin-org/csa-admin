# frozen_string_literal: true

# Handles auditing of delivery cycle changes.
#
# This concern extends the base Auditable functionality to:
# - Track changes to delivery cycle configuration attributes
# - Audit nested periods changes (similar to membership basket complements)
#
# Periods are tracked as a snapshot of the association state before and after
# changes, ensuring all modifications from a single update are captured in
# one atomic audit entry.
#
# Note: This concern uses `prepend` to capture the periods state before the
# original setter method processes the attributes. This ensures we track
# the before/after state correctly even though accepts_nested_attributes_for
# defines the setter method directly on the class.
#
module DeliveryCycle::Auditing
  extend ActiveSupport::Concern

  # Prepended module to capture periods state before the original method
  # processes the nested attributes. Also overrides audited_nested_changes
  # to ensure it takes precedence over Auditable's default implementation.
  module PeriodsTracking
    def periods_attributes=(*args)
      @tracked_periods_attributes = periods.map(&:attributes)
      super
    end

    private

    def audited_nested_changes
      change = compute_periods_change
      change ? { "periods" => change } : {}
    end
  end

  included do
    include Auditable
    prepend PeriodsTracking

    audited_attributes \
      :member_order_priority,
      :price,
      :absences_included_annually,
      :wdays,
      :first_cweek,
      :last_cweek,
      :exclude_cweek_range,
      :week_numbers,
      :names,
      :public_names,
      :invoice_names,
      :form_details
  end

  private

  def compute_periods_change
    return unless @tracked_periods_attributes

    before = serialize_periods(@tracked_periods_attributes)
    after = serialize_periods(periods.reject(&:marked_for_destruction?).map(&:attributes))

    return if before == after

    [ before, after ]
  end

  def serialize_periods(periods_attributes)
    periods_attributes
      .reject { |attrs| attrs["_destroy"] == "1" || attrs["_destroy"] == true }
      .sort_by { |attrs| [ attrs["from_fy_month"].to_i, attrs["to_fy_month"].to_i ] }
      .map { |attrs|
        {
          "from_fy_month" => attrs["from_fy_month"],
          "to_fy_month" => attrs["to_fy_month"],
          "results" => attrs["results"],
          "minimum_gap_in_days" => attrs["minimum_gap_in_days"]
        }.compact
      }
  end
end
