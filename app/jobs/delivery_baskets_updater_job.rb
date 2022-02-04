class DeliveryBasketsUpdaterJob < ApplicationJob
  queue_as :default

  def perform(date)
    fiscal_year = Current.acp.fiscal_year_for(date)
    memberships = Membership.during_year(fiscal_year.year)
    MembershipBasketsUpdater.perform_all!(memberships)
  end
end
