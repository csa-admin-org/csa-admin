# frozen_string_literal: true

class Notification::AdminMembershipsRenewalPending < Notification::Base
  def notify
    return unless notify_today?
    return unless pending_memberships.any? || opened_memberships.any?

    Admin.notify!(:memberships_renewal_pending,
      pending_memberships: pending_memberships.to_a,
      opened_memberships: opened_memberships.to_a,
      pending_action_url: memberships_url(renewal_state_eq: :renewal_pending),
      opened_action_url: memberships_url(renewal_state_eq: :renewal_opened),
      action_url: memberships_url)
  end

  private

  def notify_today?
    Current.fiscal_year.end_of_year == 10.days.from_now.to_date
  end

  def pending_memberships
    @pending_memberships ||= Membership.current_year.renewal_state_eq(:renewal_pending)
  end

  def opened_memberships
    @opened_memberships ||= Membership.current_year.renewal_state_eq(:renewal_opened)
  end

  def memberships_url(**options)
    Rails
      .application
      .routes
      .url_helpers
      .memberships_url(
        q: { during_year: Current.fy_year }.merge(options),
        scope: :all,
        host: Current.org.admin_url)
  end
end
