# frozen_string_literal: true

class Notification::MembershipRenewalReminder < Notification::Base
  mail_template :membership_renewal_reminder

  def notify
    return unless mail_template_active?
    return unless reminder_delay_in_days

    eligible_memberships.each do |membership|
      deliver_later(membership: membership)
      membership.touch(:renewal_reminder_sent_at)
    end
  end

  private

  def reminder_delay_in_days
    Current.org.open_renewal_reminder_sent_after_in_days
  end

  def eligible_memberships
    Membership
      .current
      .not_renewed
      .where(renew: true)
      .where(renewal_reminder_sent_at: nil)
      .where(renewal_opened_at: ..reminder_delay_in_days.days.ago)
      .includes(:member)
      .select(&:can_send_email?)
  end
end
