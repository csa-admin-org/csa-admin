# frozen_string_literal: true

module DeliveryCycle::Visibility
  extend ActiveSupport::Concern

  included do
    has_and_belongs_to_many :depots, -> { kept }
  end

  class_methods do
    def visible?
      delivery_cycle_visibility_cache[:visible]
    end

    def shared_depots?
      delivery_cycle_visibility_cache[:shared_depots]
    end

    def visible_records
      delivery_cycle_visibility_cache[:records]
    end

    # Prioritize visible delivery cycles over non-visible ones, even if a
    # non-visible cycle has more billable deliveries.
    def primary
      visible_records.max_by { |dc| [ dc.billable_deliveries_count, dc.depot_ids.size ] }
        || kept.max_by { |dc| [ dc.billable_deliveries_count, dc.depot_ids.size ] }
    end

    def member_form_deliveries_year(membership = nil)
      if membership
        membership.fy_year + 1
      else
        (Delivery.next&.fiscal_year || Current.fiscal_year).year
      end
    end

    def for_member_form(membership = nil, only_with_future_deliveries: false)
      ids = Depot.for_member_form(membership).includes(:delivery_cycles).flat_map(&:delivery_cycle_ids)
      ids << membership.delivery_cycle_id if membership
      cycles = where(id: ids.uniq).kept.includes(:depots).member_ordered.to_a
      if only_with_future_deliveries
        year = member_form_deliveries_year(membership)
        cycles.select! { |dc| dc.deliveries_count_for(year).positive? }
      end
      cycles
    end

    def member_ordered
      kept.to_a.sort_by { |dc|
        clauses = [ dc.member_order_priority ]
        clauses <<
          case Current.org.delivery_cycles_member_order_mode
          when "deliveries_count_asc"; dc.billable_deliveries_count
          when "deliveries_count_desc"; -dc.billable_deliveries_count
          when "wdays_asc"; [ dc.wdays.sort, -dc.billable_deliveries_count ]
          end
        clauses << dc.public_name
        clauses
      }
    end

    private

    def delivery_cycle_visibility_cache
      Current.delivery_cycle_visibility ||= begin
        cycles = visible.preload(:depots, :periods).to_a
        shared = cycles.flat_map(&:depot_ids).tally.values.any? { |count| count > 1 }
        { visible: cycles.many? && shared, shared_depots: shared, records: cycles }
      end
    end
  end

  def primary?
    self == self.class.primary
  end

  def visible?
    depots.visible.any?
  end
end
