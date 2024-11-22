# frozen_string_literal: true

module Notifier
  extend self

  def send_all_daily
    send_invoice_overdue_notice_emails

    send_admin_delivery_list_emails
    send_admin_memberships_renewal_pending_emails

    send_membership_initial_basket_emails
    send_membership_final_basket_emails
    send_membership_first_basket_emails
    send_membership_last_basket_emails
    send_membership_last_trial_basket_emails
    send_membership_renewal_reminder_emails

    send_activity_participation_reminder_emails
    send_activity_participation_validated_emails
    send_activity_participation_rejected_emails
  end

  def send_all_hourly
    send_admin_new_activity_participation_emails
  end

  def send_invoice_overdue_notice_emails
    return unless Current.org.send_invoice_overdue_notice?

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
    delays = [ 10, 4 ].map { |d| d.days.from_now.to_date }
    end_of_fiscal_year = Current.fiscal_year.end_of_year
    return unless end_of_fiscal_year.in?(delays)

    pending_memberships = Membership.current_year.renewal_state_eq(:renewal_pending)
    opened_memberships = Membership.current_year.renewal_state_eq(:renewal_opened)
    return unless pending_memberships.any? || opened_memberships.any?

    Admin.notify!(:memberships_renewal_pending,
      pending_memberships: pending_memberships.to_a,
      opened_memberships: opened_memberships.to_a,
      pending_action_url: memberships_url(renewal_state_eq: :renewal_pending),
      opened_action_url: memberships_url(renewal_state_eq: :renewal_opened),
      action_url: memberships_url)
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

  def send_membership_initial_basket_emails
    return unless MailTemplate.active_template(:membership_initial_basket)

    baskets =
      Membership
        .current
        .includes(:member, baskets: :delivery)
        .select(&:can_send_email?)
        .map { |m| m.baskets.deliverable.first }
        .select { |b| b.delivery.date.today? }

    baskets.each do |b|
      member = b.member
      next if member.initial_basket_sent_at? && member.initial_basket_sent_at >= b.member.activated_at
      next if b.membership.previous_membership&.renewed?

      MailTemplate.deliver_later(:membership_initial_basket, basket: b)
      member.touch(:initial_basket_sent_at)
    end
  end

  def send_membership_final_basket_emails
    return unless MailTemplate.active_template(:membership_final_basket)

    baskets =
      Membership
        .current
        .renewal_state_eq(:renewal_canceled)
        .includes(:member, baskets: :delivery)
        .select(&:can_send_email?)
        .map { |m| m.baskets.deliverable.last }
        .select { |b| b.delivery.date.today? }

    baskets.each do |b|
      member = b.member
      next if member.final_basket_sent_at? && member.final_basket_sent_at >= b.member.activated_at

      MailTemplate.deliver_later(:membership_final_basket, basket: b)
      member.touch(:final_basket_sent_at)
    end
  end

  def send_membership_first_basket_emails
    return unless MailTemplate.active_template(:membership_first_basket)

    baskets =
      Membership
        .current
        .where(first_basket_sent_at: nil)
        .includes(:member, baskets: :delivery)
        .select(&:can_send_email?)
        .map { |m| m.baskets.deliverable.first }
        .select { |b| b.delivery.date.today? }

    baskets.each do |b|
      MailTemplate.deliver_later(:membership_first_basket, basket: b)
      b.membership.touch(:first_basket_sent_at)
    end
  end

  def send_membership_last_basket_emails
    return unless MailTemplate.active_template(:membership_last_basket)

    baskets =
      Membership
        .current
        .where(last_basket_sent_at: nil)
        .includes(:member, baskets: :delivery)
        .select(&:can_send_email?)
        .map { |m| m.baskets.deliverable.last }
        .select { |b| b.delivery.date.today? }

    baskets.each do |b|
      MailTemplate.deliver_later(:membership_last_basket, basket: b)
      b.membership.touch(:last_basket_sent_at)
    end
  end

  def send_membership_last_trial_basket_emails
    return unless MailTemplate.active_template(:membership_last_trial_basket)

    baskets =
      Membership
        .trial
        .where(last_trial_basket_sent_at: nil)
        .includes(:member, baskets: :delivery)
        .select(&:can_send_email?)
        .reject(&:trial_only?)
        .map { |m| m.baskets.trial.last }
        .select { |b| b.delivery.date.today? }

    baskets.each do |b|
      MailTemplate.deliver_later(:membership_last_trial_basket, basket: b)
      b.membership.touch(:last_trial_basket_sent_at)
    end
  end

  def send_membership_renewal_reminder_emails
    return unless MailTemplate.active_template(:membership_renewal_reminder)

    in_days = Current.org.open_renewal_reminder_sent_after_in_days
    return unless in_days

    memberships =
      Membership
        .current
        .not_renewed
        .where(renew: true)
        .where(renewal_reminder_sent_at: nil)
        .where(renewal_opened_at: ..in_days.days.ago)
        .includes(:member)
        .select(&:can_send_email?)

    memberships.each do |m|
      MailTemplate.deliver_later(:membership_renewal_reminder, membership: m)
      m.touch(:renewal_reminder_sent_at)
    end
  end

  def send_activity_participation_reminder_emails
    return unless Current.org.feature?("activity")

    participations =
      ActivityParticipation
        .future
        .includes(:activity, :member)
        .select(&:reminderable?)
        .select(&:can_send_email?)

    ActivityParticipationGroup.group(participations).each do |group|
      MailTemplate.deliver_later(:activity_participation_reminder,
        activity_participation_ids: group.ids)
      group.touch(:latest_reminder_sent_at)
    end
  end

  def send_activity_participation_validated_emails
    return unless Current.org.feature?("activity")
    return unless MailTemplate.active_template(:activity_participation_validated)

    participations =
      ActivityParticipation
        .where(validated_at: 3.days.ago..)
        .review_not_sent
        .includes(:activity, :member)
        .select(&:can_send_email?)

    ActivityParticipationGroup.group(participations).each do |group|
      MailTemplate.deliver_later(:activity_participation_validated,
        activity_participation_ids: group.ids)
      group.touch(:review_sent_at)
    end
  end

  def send_activity_participation_rejected_emails
    return unless Current.org.feature?("activity")
    return unless MailTemplate.active_template(:activity_participation_rejected)

    participations =
      ActivityParticipation
        .where(rejected_at: 3.days.ago..)
        .review_not_sent
        .includes(:activity, :member)
        .select(&:can_send_email?)

    ActivityParticipationGroup.group(participations).each do |group|
      MailTemplate.deliver_later(:activity_participation_rejected,
        activity_participation_ids: group.ids)
      group.touch(:review_sent_at)
    end
  end

  def send_admin_new_activity_participation_emails
    return unless Current.org.feature?("activity")

    participations =
      ActivityParticipation
        .where(created_at: 1.day.ago.., admins_notified_at: nil)
        .includes(:activity, :member, :session)

    ActivityParticipationGroup.group(participations).each do |group|
      attrs = {
        activity_participation_ids: group.ids,
        skip: group.session&.admin
      }
      Admin.notify!(:new_activity_participation, **attrs)
      Admin.notify!(:new_activity_participation_with_note, **attrs) if group.note?
      group.touch(:admins_notified_at)
    end
  end
end
