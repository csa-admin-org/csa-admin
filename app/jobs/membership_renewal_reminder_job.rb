# frozen_string_literal: true

class MembershipRenewalReminderJob < ApplicationJob
  queue_as :low

  # A retried or duplicate enqueue for the same membership waits, then the
  # notification no-ops once the reminder is recorded.
  limits_concurrency key: ->(membership, context) { [ membership.id, context["tenant"] ] }

  def perform(membership)
    Notification::MembershipRenewalReminder.new.deliver_to(membership)
  end
end
