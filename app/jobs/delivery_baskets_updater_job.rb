# frozen_string_literal: true

class DeliveryBasketsUpdaterJob < ApplicationJob
  queue_as :default
  limits_concurrency key: ->(year, context) { [ year, context["tenant"] ] }

  def perform(year)
    memberships = Membership.during_year(year)
    MembershipBasketsUpdater.perform_all!(memberships)
  end
end
