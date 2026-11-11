# frozen_string_literal: true

class Notification::MembershipRenewalReminder < Notification::Base
  mail_template :membership_renewal_reminder

  def notify
    return unless mail_template_active?

    memberships = deliverable_memberships
    return if memberships.empty?

    # One job per membership, inserted in a single queue transaction.
    # The parent run stays flat as the tenant grows; each child sends at most one email.
    jobs = memberships.map { |membership| MembershipRenewalReminderJob.new(membership) }
    ActiveJob.perform_all_later(jobs)
  end

  def deliver_to(membership)
    return unless mail_template_active?

    # after_initialize assigns new_config_from, which is not a column. lock!
    # refuses a record that already has unsaved changes.
    membership.clear_changes_information
    membership.with_lock do
      return unless still_due?(membership)

      # The previous per-member loop committed the email before the stamp.
      # A retry must not send that reminder again.
      if reminder_recorded?(membership)
        mark_sent!(membership)
        return
      end

      deliver(membership: membership)
      mark_sent!(membership)
    end
  end

  private

  def reminder_delay_in_days
    MailTemplate.delay_in_days_for("membership_renewal_reminder")
  end

  def deliverable_memberships
    memberships = candidates.includes(:member).to_a
    return [] if memberships.empty?

    addresses = memberships.flat_map { |membership| membership.member.emails_array }
    suppressed = if addresses.empty?
      Set.new
    else
      EmailSuppression.outbound.active.where(email: addresses).pluck(:email).to_set
    end

    memberships.select { |membership|
      membership.member.emails_array.any? { |email| !suppressed.include?(email) }
    }
  end

  def candidates
    Membership
      .current
      .not_renewed
      .where(renew: true, renewal_reminder_sent_at: nil)
      .where(renewal_opened_at: ..reminder_delay_in_days.days.ago)
  end

  def still_due?(membership)
    membership.renewal_reminder_sent_at.nil? &&
      membership.renew? &&
      !membership.renewed? &&
      membership.current? &&
      membership.renewal_opened_at.present? &&
      membership.renewal_opened_at <= reminder_delay_in_days.days.ago &&
      membership.can_send_email?
  end

  def reminder_recorded?(membership)
    MailDelivery.for_mailable(membership).exists?(action: mail_template.action)
  end

  # update_columns, not touch. Membership after_touch recalculates every basket,
  # invoice, and price. That sync is what made the nightly run grow with tenant size.
  def mark_sent!(membership)
    membership.update_columns(
      renewal_reminder_sent_at: Time.current,
      updated_at: Time.current)
  end
end
