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

    @membership.transaction do
      destroy_basket_shifts_for_obsolete_deliveries!
      baskets.where(delivery_id: obsolete_delivery_ids).find_each(&:destroy!)
      future_deliveries.each do |delivery|
        unless baskets.exists?(delivery_id: delivery.id)
          @membership.create_basket!(delivery)
        end
      end
      @membership.save!
    end
  end

  private

  def range
    [ Date.current, @membership.started_on ].max..@membership.ended_on
  end

  def baskets
    @membership.baskets.between(range.min..@membership.fiscal_year.end_of_year)
  end

  def future_deliveries
    @future_deliveries ||= @membership.delivery_cycle.deliveries_in(range)
  end

  def obsolete_delivery_ids
    @obsolete_delivery_ids ||= baskets.where.not(delivery_id: future_deliveries).pluck(:delivery_id)
  end

  def destroy_basket_shifts_for_obsolete_deliveries!
    return if obsolete_delivery_ids.empty?

    @membership
      .basket_shifts
      .where(source_delivery_id: obsolete_delivery_ids)
      .or(@membership.basket_shifts.where(target_delivery_id: obsolete_delivery_ids))
      .find_each(&:destroy!)
  end
end
