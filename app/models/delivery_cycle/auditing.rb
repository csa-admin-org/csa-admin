# frozen_string_literal: true

# Uses `prepend` to capture state before accepts_nested_attributes_for
# setter methods process the attributes.
module DeliveryCycle::Auditing
  extend ActiveSupport::Concern

  module NestedChangesTracking
    def periods_attributes=(*args)
      @tracked_periods_attributes = periods.map(&:attributes)
      super
    end

    def depot_ids=(ids)
      @tracked_depot_ids = depot_ids.dup
      super
    end

    private

    def audited_nested_changes
      changes = {}

      if (periods_change = compute_periods_change)
        changes["periods"] = periods_change
      end

      if (depot_ids_change = compute_depot_ids_change)
        changes["depot_ids"] = depot_ids_change
      end

      changes
    end
  end

  included do
    include Auditable
    prepend NestedChangesTracking

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

  def compute_depot_ids_change
    return unless @tracked_depot_ids

    before = @tracked_depot_ids.sort
    after = depot_ids.sort

    return if before == after

    [ before, after ]
  end

  def compute_periods_change
    return unless @tracked_periods_attributes

    before_all = serialize_periods(@tracked_periods_attributes)
    after_all = serialize_periods(periods.reject(&:marked_for_destruction?).map(&:attributes))

    return if before_all == after_all

    before_by_id = before_all.index_by { |p| period_key(p) }
    after_by_id = after_all.index_by { |p| period_key(p) }

    all_ids = (before_by_id.keys | after_by_id.keys).sort_by(&:to_i)

    before_changed = []
    after_changed = []

    all_ids.each do |id|
      before_period = before_by_id[id]
      after_period = after_by_id[id]

      next if before_period == after_period

      before_changed << before_period if before_period
      after_changed << after_period if after_period
    end

    [ before_changed, after_changed ]
  end

  def serialize_periods(periods_attributes)
    periods_attributes
      .reject { |attrs| attrs["_destroy"] == "1" || attrs["_destroy"] == true }
      .sort_by { |attrs| attrs["id"].to_i }
      .map { |attrs|
        {
          "id" => attrs["id"],
          "from_fy_month" => attrs["from_fy_month"],
          "to_fy_month" => attrs["to_fy_month"],
          "results" => attrs["results"]
        }.compact
      }
  end

  def period_key(period)
    period["id"]
  end
end
