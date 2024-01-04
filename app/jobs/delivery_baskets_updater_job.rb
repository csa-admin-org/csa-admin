class DeliveryBasketsUpdaterJob < ApplicationJob
  queue_as :default
  unique :until_executing, on_conflict: :log

  # _tenant is a hack to make this job unique per tenant, as activejob-uniqueness
  # doesn't support the Sidekiq tags used to switch tenant.
  def perform(year, _tenant)
    memberships = Membership.during_year(year)
    MembershipBasketsUpdater.perform_all!(memberships)
  end
end
