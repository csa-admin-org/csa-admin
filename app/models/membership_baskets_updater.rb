# frozen_string_literal: true

class MembershipBasketsUpdater
  def self.perform_all!(memberships)
    memberships.find_each { |m| new(m).perform! }
  end

  def initialize(membership, cycle: nil)
    @membership = membership
    @cycle = cycle || membership.delivery_cycle
  end

  # Shifts perform! would destroy for this membership. No writes.
  # A conflicting basket override skips the resync, so nothing is dropped.
  def shifts_to_drop
    return [] if @membership.past? || overrides.conflicts.any?

    shifts_for_obsolete_deliveries.includes(
      :absence,
      :source_delivery,
      :target_delivery,
      membership: [ :member, :baskets ]
    ).to_a
  end

  def perform!
    return if @membership.past?
    return log_basket_override_conflicts if overrides.conflicts.any?

    ActiveRecord::Base.no_touching do
      @membership.transaction do
        destroy_basket_shifts_for_obsolete_deliveries!
        baskets.where(delivery_id: obsolete_delivery_ids).find_each(&:destroy!)
        overrides.reapply!(create_missing_baskets!)
      end
    end
    @membership.refresh_after_baskets_update!
  end

  private

  def range
    [ Date.current, @membership.started_on ].max..@membership.ended_on
  end

  def baskets
    @membership.baskets.between(range.min..@membership.fiscal_year.end_of_year)
  end

  def desired_deliveries
    @desired_deliveries ||= begin
      scheduled = @cycle.deliveries_in(range)
      overrides.desired_deliveries(scheduled)
    end
  end

  def obsolete_delivery_ids
    @obsolete_delivery_ids ||= begin
      ids = baskets.where.not(delivery_id: desired_deliveries).pluck(:delivery_id)
      ids - off_cycle_shift_receptacle_ids(ids)
    end
  end

  # An off-cycle target is missing from the cycle on purpose. Keep it when the
  # basket holds only what was shifted onto it, from one or more shifts, and at
  # least one source delivery is still there. A target the cycle just dropped
  # still has its own quantity on top, so it stays obsolete.
  def off_cycle_shift_receptacle_ids(obsolete_ids)
    return [] if obsolete_ids.empty?

    obsolete = obsolete_ids.to_set
    @membership.basket_shifts.includes(:target_delivery).group_by(&:target_delivery_id)
      .filter_map { |delivery_id, shifts|
        next unless obsolete.include?(delivery_id)
        next unless shifts.any? { |shift| obsolete.exclude?(shift.source_delivery_id) }

        delivery = shifts.first.target_delivery
        basket = shifts.first.target_basket
        next unless delivery && basket
        next if @cycle.include_delivery?(delivery)

        shifted_qty = shifts.sum { |shift|
          shift.quantities[:basket_size]&.values&.first.to_i
        }
        delivery_id if basket.quantity.to_i == shifted_qty
      }
  end

  def create_missing_baskets!
    existing_ids = baskets.where(delivery_id: desired_deliveries).pluck(:delivery_id).to_set
    desired_deliveries
      .reject { |delivery| existing_ids.include?(delivery.id) }
      .map { |delivery| @membership.create_basket!(delivery).delivery_id }
  end

  def destroy_basket_shifts_for_obsolete_deliveries!
    return if obsolete_delivery_ids.empty?

    shifts_for_obsolete_deliveries.find_each do |shift|
      Rails.logger.info("[BasketShift] destroying during basket resync " \
        "tenant=#{Tenant.current} membership=#{@membership.id} shift=#{shift.id} " \
        "source_delivery=#{shift.source_delivery_id} target_delivery=#{shift.target_delivery_id}")
      shift.destroy!
    end
  end

  def shifts_for_obsolete_deliveries
    @membership
      .basket_shifts
      .where(source_delivery_id: obsolete_delivery_ids)
      .or(@membership.basket_shifts.where(target_delivery_id: obsolete_delivery_ids))
  end

  def overrides
    @overrides ||= Overrides.new(@membership, range)
  end

  def log_basket_override_conflicts
    Rails.logger.warn("[BasketOverride] skipping basket resync " \
      "tenant=#{Tenant.current} membership=#{@membership.id} conflicts=#{overrides.conflicts}")
  end
end
