class DeliveryBasketsUpdaterJob < ApplicationJob
  queue_as :default
  unique :until_executing, on_conflict: :log

  def perform(year)
    memberships = Membership.during_year(year)
    MembershipBasketsUpdater.perform_all!(memberships)
  end

  private

  def lock_key_arguments
    [ Current.acp.tenant_name ] + arguments
  end
end
