# frozen_string_literal: true

class MembershipRenewalJob < ApplicationJob
  queue_as :default
  limits_concurrency key: ->(membership, context) { [ membership.id, context["tenant"] ] }

  def perform(membership)
    membership.renew!
  end
end
