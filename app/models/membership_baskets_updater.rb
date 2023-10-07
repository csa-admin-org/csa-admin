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
      ensure_valid_deliveries_cycle!
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

  def ensure_valid_deliveries_cycle!
    unless @membership.depot.deliveries_cycles.include?(@membership.deliveries_cycle)
      new_cycle = @membership.depot.main_deliveries_cycle
      @membership.update_column(:deliveries_cycle_id, new_cycle.id)
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
    @future_deliveries ||= @membership.deliveries_cycle.deliveries_in(range)
  end
end
