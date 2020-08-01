class MembershipOpenRenewalJob < ApplicationJob
  queue_as :default

  def perform(membership)
    membership.open_renewal!
  end
end
