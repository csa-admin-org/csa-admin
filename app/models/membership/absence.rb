# frozen_string_literal: true

# Handles absence-related state management for memberships.
#
# This concern manages the relationship between absences (member-created),
# forced deliveries (admin or system-created), and the resulting basket states.
#
# Basket states priority (highest to lowest):
#   1. forced - Member explicitly wants this delivery
#   2. absent (definitive) - Linked to an Absence record
#   3. absent (provisional) - Auto-assigned from absences_included quota
#
# Usage:
#   membership.update_absent_baskets!      # Recalculate all basket absence states
#   membership.update_not_billable_baskets! # Update billing based on absence state
#
module Membership::Absence
  extend ActiveSupport::Concern

  included do
    validates :absences_included_annually, numericality: true

    before_validation :set_absences_included_annually_default
    after_commit :update_absences_included!, on: %i[create update]
  end

  private

  def set_absences_included_annually_default
    self.absences_included_annually ||= delivery_cycle&.absences_included_annually
  end

  # Calculates the prorated absences_included for this membership based on
  # the number of baskets relative to a full year of the delivery cycle.
  def update_absences_included!
    return unless Current.org.feature?("absence")

    full_year = delivery_cycle.deliveries_in(fiscal_year.range).size.to_f
    total = (baskets.count / full_year * absences_included_annually).round
    unless total == absences_included
      update_column(:absences_included, total)
    end
  end

  # Recalculates basket states based on forced deliveries, absences, and
  # the provisional absence quota. Called whenever membership or related
  # records change.
  def update_absent_baskets!
    return unless Current.org.feature?("absence")
    return if destroyed?

    transaction do
      # Reset absent and forced states
      baskets.absent_or_forced.update_all(state: "normal", absence_id: nil)

      # 1. Apply forced deliveries (highest priority)
      forced_delivery_ids = forced_deliveries.pluck(:delivery_id)
      baskets.where(delivery_id: forced_delivery_ids).update_all(state: "forced")

      # 2. Apply definitive absences (second priority)
      # Note: Definitive absences can override trial state but not forced state
      member.absences.overlaps(period).each do |absence|
        baskets
          .not_forced
          .between(absence.date_range)
          .update_all(state: "absent", absence_id: absence.id)
      end

      # 3. Apply provisional absences (lowest priority)
      remaining = absences_included - baskets.absent_or_forced.count
      if remaining.positive?
        baskets
          .normal
          .reorder("deliveries.date DESC")
          .limit(remaining)
          .update_all(state: "absent")
      end
    end
  end

  # Updates basket billable status based on absence state and organization
  # billing configuration.
  def update_not_billable_baskets!
    return unless Current.org.feature?("absence")
    return if destroyed?

    transaction do
      baskets.not_billable.update_all(billable: true)
      absent_baskets = baskets.absent
      if Current.org.absences_billed?
        absent_baskets = absent_baskets.limit(absences_included)
      end
      absent_baskets.update_all(billable: false)
      baskets.find_each(&:update_calculated_price_extra!)
    end
  end
end
