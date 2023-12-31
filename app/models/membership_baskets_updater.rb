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

  def range
    [ Date.today, @membership.started_on ].max..@membership.ended_on
  end

  def baskets
    @membership.baskets.between(range.min..@membership.fiscal_year.end_of_year)
  end

  def future_deliveries
    @future_deliveries ||= @membership.delivery_cycle.deliveries_in(range)
  end
end
