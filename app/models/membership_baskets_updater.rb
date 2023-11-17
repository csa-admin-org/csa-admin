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
      ensure_valid_delivery_cycle!
      baskets.where.not(delivery_id: future_deliveries).find_each(&:destroy!)
      future_deliveries.each do |delivery|
        unless baskets.exists?(delivery_id: delivery.id)
          @membership.create_basket!(delivery)
        end
      end
      @membership.save!
    end
  end

  private

  def ensure_valid_delivery_cycle!
    if !@membership.valid? && @membership.errors[:delivery_cycle].any?
      new_cycle = (
        @membership.depot.delivery_cycles & @membership.basket_size.delivery_cycles
      ).max_by(&:deliveries_count)
      @membership.update_column(:delivery_cycle_id, new_cycle.id)
      @membership.reload
    end
  end

  def range
    [Date.today, @membership.started_on].max..@membership.ended_on
  end

  def baskets
    @membership.baskets.between(range.min..@membership.fiscal_year.end_of_year)
  end

  def future_deliveries
    @future_deliveries ||= @membership.delivery_cycle.deliveries_in(range)
  end
end
