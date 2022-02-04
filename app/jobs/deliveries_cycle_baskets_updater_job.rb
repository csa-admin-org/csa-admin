class DeliveriesCycleBasketsUpdaterJob < ApplicationJob
  queue_as :default

  def perform(deliveries_cycle)
    MembershipBasketsUpdater.perform_all!(deliveries_cycle.memberships)
  end
end
