module Notifier
  extend self

  def send_all
    send_invoice_overdue_notice_emails
    send_admin_delivery_list_emails
    send_admin_memberships_renewal_pending_emails
    send_membership_renewal_reminder_emails
    send_membership_last_trial_basket_emails
    send_activity_participation_reminder_emails
    send_activity_participation_validated_emails
    send_activity_participation_rejected_emails
  end

  def send_invoice_overdue_notice_emails
    return unless Current.acp.send_invoice_overdue_notice?

    Invoice.open.each { |i| InvoiceOverdueNoticer.perform(i) }
  end

  def send_admin_delivery_list_emails
    next_delivery = Delivery.next
    return unless next_delivery
    return unless Date.current == (next_delivery.date - 1.day)

    next_delivery.depots.select(&:emails?).each do |depot|
      AdminMailer.with(
        depot: depot,
        delivery: next_delivery
      ).depot_delivery_list_email.deliver_later
    end
    Admin.notify!(:delivery_list, delivery: next_delivery)
  end

  def send_admin_memberships_renewal_pending_emails
    delays = [10, 4].map{ |d| d.days.from_now.to_date }
    end_of_fiscal_year = Current.fiscal_year.end_of_year
    return unless end_of_fiscal_year.in?(delays)

    memberships = Membership.current_year.renewal_state_eq(:renewal_pending)
    return if memberships.empty?

    action_url =
      Rails
        .application
        .routes
        .url_helpers
        .memberships_url(
          q: { renewal_state_eq: 'renewal_pending', during_year: Current.fy_year },
          scope: :all,
          host: Current.acp.email_default_host)
    Admin.notify!(:memberships_renewal_pending,
      memberships: memberships.to_a,
      action_url: action_url)
  end

  def send_membership_renewal_reminder_emails
    return unless MailTemplate.active_template(:membership_renewal_reminder)

    in_days = Current.acp.open_renewal_reminder_sent_after_in_days
    return unless in_days

    memberships =
      Membership
        .current
        .not_renewed
        .where(renew: true)
        .where(renewal_reminder_sent_at: nil)
        .where('renewal_opened_at <= ?', in_days.days.ago)
        .includes(:member)
        .select(&:can_send_email?)

    memberships.each do |m|
      MailTemplate.deliver_later(:membership_renewal_reminder, membership: m)
      m.touch(:renewal_reminder_sent_at)
    end
  end

  def send_membership_last_trial_basket_emails
    return unless MailTemplate.active_template(:membership_last_trial_basket)

    memberships =
      Membership
        .trial
        .where(last_trial_basket_sent_at: nil)
        .includes(baskets: :delivery)
        .select(&:can_send_email?)
        .reject(&:trial_only?)
        .select { |m| m.baskets.trial.last.delivery.date.today? }

    memberships.each do |m|
      last_trial_basket = m.baskets.trial.last
      MailTemplate.deliver_later(:membership_last_trial_basket,
        basket: last_trial_basket)
      m.touch(:last_trial_basket_sent_at)
    end
  end

  def send_activity_participation_reminder_emails
    return unless Current.acp.feature?('activity')

    participations =
      ActivityParticipation
        .future
        .includes(:activity, :member)
        .select(&:reminderable?)
        .select(&:can_send_email?)

    ActivityParticipationGroup.group(participations).each do |parts|
      MailTemplate.deliver_later(:activity_participation_reminder,
        activity_participation_ids: parts.map(&:id))
      parts.each { |p| p.touch(:latest_reminder_sent_at) }
    end
  end

  def send_activity_participation_validated_emails
    return unless Current.acp.feature?('activity')
    return unless MailTemplate.active_template(:activity_participation_validated)

    participations =
      ActivityParticipation
        .where('validated_at >= ?', 3.days.ago)
        .review_not_sent
        .includes(:activity, :member)
        .select(&:can_send_email?)

    ActivityParticipationGroup.group(participations).each do |parts|
      MailTemplate.deliver_later(:activity_participation_validated,
        activity_participation_ids: parts.map(&:id))
      parts.each { |p| p.touch(:review_sent_at) }
    end
  end

  def send_activity_participation_rejected_emails
    return unless Current.acp.feature?('activity')
    return unless MailTemplate.active_template(:activity_participation_rejected)

    participations =
      ActivityParticipation
        .where('rejected_at >= ?', 3.days.ago)
        .review_not_sent
        .includes(:activity, :member)
        .select(&:can_send_email?)

    ActivityParticipationGroup.group(participations).each do |parts|
      MailTemplate.deliver_later(:activity_participation_rejected,
        activity_participation_ids: parts.map(&:id))
      parts.each { |p| p.touch(:review_sent_at) }
    end
  end
end
