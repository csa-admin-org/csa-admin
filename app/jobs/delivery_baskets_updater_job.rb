class DeliveryBasketsUpdaterJob < ApplicationJob
  queue_as :default

  def perform(year)
    memberships = Membership.during_year(year)
    MembershipBasketsUpdater.perform_all!(memberships)
  end
end
