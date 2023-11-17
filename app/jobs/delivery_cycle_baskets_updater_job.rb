class DeliveryCycleBasketsUpdaterJob < ApplicationJob
  queue_as :default

  def perform(delivery_cycle)
    MembershipBasketsUpdater.perform_all!(delivery_cycle.memberships.current_or_future)
  end
end
