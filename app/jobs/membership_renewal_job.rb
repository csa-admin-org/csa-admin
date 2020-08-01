class MembershipRenewalJob < ApplicationJob
  queue_as :default

  def perform(membership)
    membership.renew!
  end
end
