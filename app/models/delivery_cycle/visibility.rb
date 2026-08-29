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

    # Prioritize visible delivery cycles over non-visible ones, even if a
    # non-visible cycle has more billable deliveries.
    def primary
      visible.max_by { |dc| [ dc.billable_deliveries_count, dc.depot_ids.size ] }
        || kept.max_by { |dc| [ dc.billable_deliveries_count, dc.depot_ids.size ] }
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
        cycles = visible.preload(:depots).to_a
        shared = cycles.flat_map(&:depot_ids).tally.values.any? { |count| count > 1 }
        { visible: cycles.many? && shared, shared_depots: shared }
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
