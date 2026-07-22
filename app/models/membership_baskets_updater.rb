# frozen_string_literal: true

class MembershipBasketsUpdater
  def self.perform_all!(memberships)
    memberships.find_each { |m| new(m).perform! }
  end

  def initialize(membership)
    @membership = membership
  end

  def perform!
    return if @membership.past?
    return log_basket_override_conflicts if overrides.conflicts.any?

    @membership.transaction do
      destroy_basket_shifts_for_obsolete_deliveries!
      baskets.where(delivery_id: obsolete_delivery_ids).find_each(&:destroy!)
      overrides.reapply!(create_missing_baskets!)
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
      scheduled = @membership.delivery_cycle.deliveries_in(range)
      overrides.desired_deliveries(scheduled)
    end
  end

  def obsolete_delivery_ids
    @obsolete_delivery_ids ||= baskets.where.not(delivery_id: desired_deliveries).pluck(:delivery_id)
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
