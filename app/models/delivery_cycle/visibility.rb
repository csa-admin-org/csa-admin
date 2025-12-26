# frozen_string_literal: true

# Handles visibility and ordering logic for delivery cycles.
# This includes determining which cycles are visible to members,
# finding the primary cycle, and ordering cycles for member display.
module DeliveryCycle::Visibility
  extend ActiveSupport::Concern

  included do
    has_and_belongs_to_many :depots, -> { kept }
  end

  class_methods do
    def visible?
      visible.many? && shared_depots?
    end

    def shared_depots?
      visible.flat_map(&:depot_ids).tally.values.any? { |count| count > 1 }
    end

    # Prioritize visible delivery cycles over non-visible ones, even if a
    # non-visible cycle has more billable deliveries.
    def primary
      visible.max_by { |dc| [ dc.billable_deliveries_count, dc.depot_ids.size ] } ||
        kept.max_by { |dc| [ dc.billable_deliveries_count, dc.depot_ids.size ] }
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
  end

  def primary?
    self == self.class.primary
  end

  def visible?
    depots.visible.any?
  end
end
