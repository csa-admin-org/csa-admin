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

    total = AbsencesIncluded.new(self).count
    update_column(:absences_included, total) unless total == absences_included
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
      remaining = absences_included - baskets_counting_as_absences_included.absent_or_forced.count
      if remaining.positive?
        provisional_absence_candidates
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
      absent_baskets =
        if Current.org.absences_billed?
          baskets_counting_as_absences_included.absent.limit(absences_included)
        else
          baskets.absent
        end
      absent_baskets.update_all(billable: false)
      baskets.includes(:baskets_basket_complements, :membership)
        .find_each(&:write_calculated_price_extra!)
    end
  end

  # Shifted sources are delivered on their target dates and do not consume the
  # included absence quota.
  def baskets_counting_as_absences_included
    baskets.where.not(delivery_id: basket_shifts.select(:source_delivery_id))
  end

  # A target receiving shifted content must remain deliverable when the freed
  # included absence is provisionally allocated elsewhere.
  def provisional_absence_candidates
    baskets.normal.where.not(delivery_id: basket_shifts.select(:target_delivery_id))
  end
end
