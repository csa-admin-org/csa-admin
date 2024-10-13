# frozen_string_literal: true

class DeliveryBasketsUpdaterJob < ApplicationJob
  queue_as :default
  limits_concurrency key: ->(year, tenant) { [ year, tenant ] }

  # _tenant argument is a needed to make this job concurrency unique per tenant
  def perform(year, _tenant)
    memberships = Membership.during_year(year)
    MembershipBasketsUpdater.perform_all!(memberships)
  end
end
