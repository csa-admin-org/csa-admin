# frozen_string_literal: true

require "test_helper"

class Notification::MembershipRenewalReminderTest < ActiveSupport::TestCase
  test "notify sends renewal reminder emails" do
    mail_templates(:membership_renewal_reminder).update!(active: true, delay_in_days: 10)
    member = create_member(emails: "anybody@doe.com")

    travel_to "2024-01-01"
    create_membership(renewal_opened_at: nil)
    create_membership(renewal_opened_at: "2024-09-01", member: create_member).update_columns(renewed_at: "2024-09-02")
    membership = create_membership(renewal_opened_at: "2024-09-01", member: member)
    create_membership(renewal_opened_at: "2024-09-01", member: create_member, renewal_reminder_sent_at: "2024-09-10")
    travel_to "2023-01-01"
    create_membership(renewal_opened_at: "2024-09-01")
    basket_updated_at = membership.baskets.maximum(:updated_at)

    travel_to "2024-09-11"
    assert_difference -> { MembershipMailer.deliveries.size }, 1 do
      deliver_reminders
    end

    membership.reload
    assert_equal Time.current, membership.renewal_reminder_sent_at
    assert_equal basket_updated_at, membership.baskets.maximum(:updated_at)

    mail = MembershipMailer.deliveries.last
    assert_equal "Renew your membership (reminder)", mail.subject
    assert_equal [ "anybody@doe.com" ], mail.to

    travel_to "2024-09-12"
    assert_no_difference -> { MembershipMailer.deliveries.size } do
      deliver_reminders
    end
  end

  test "notify does not send when the reminder template is inactive" do
    mail_templates(:membership_renewal_reminder).update!(active: false, delay_in_days: 10)
    travel_to "2024-01-01"
    create_membership(renewal_opened_at: "2024-09-01", member: create_member(emails: "anybody@doe.com"))

    travel_to "2024-09-20"
    assert_no_enqueued_jobs only: MembershipRenewalReminderJob do
      Notification::MembershipRenewalReminder.notify
    end
    assert_no_difference -> { MembershipMailer.deliveries.size } do
      perform_enqueued_jobs(only: MailDelivery::ProcessJob)
    end
  end

  test "notify enqueues one job per deliverable member and looks up suppressions once" do
    mail_templates(:membership_renewal_reminder).update!(active: true, delay_in_days: 10)

    travel_to "2024-09-01"
    first = create_member(emails: "one@doe.com, two@doe.com")
    second = create_member(emails: "three@doe.com")
    blocked = create_member(emails: "blocked@doe.com")
    create_membership(renewal_opened_at: "2024-09-01", member: first)
    create_membership(renewal_opened_at: "2024-09-01", member: second)
    create_membership(renewal_opened_at: "2024-09-01", member: blocked)
    create_membership(
      renewal_opened_at: "2024-09-01",
      member: create_member,
      renewal_reminder_sent_at: Time.current)
    suppress_email("blocked@doe.com")
    clear_enqueued_jobs

    travel_to "2024-09-11"
    queries = capture_sql { Notification::MembershipRenewalReminder.notify }

    assert_equal 1, queries.count { |sql| sql.include?("email_suppressions") }
    assert_enqueued_jobs 2, only: MembershipRenewalReminderJob
    assert_no_enqueued_jobs only: MailDelivery::ProcessJob
  end

  test "a child skips a membership that was renewed after it was enqueued" do
    mail_templates(:membership_renewal_reminder).update!(active: true, delay_in_days: 10)
    member = create_member(emails: "anybody@doe.com")

    travel_to "2024-09-01"
    membership = create_membership(renewal_opened_at: "2024-09-01", member: member)

    travel_to "2024-09-11"
    Notification::MembershipRenewalReminder.notify
    membership.update_columns(renewed_at: Time.current)

    assert_no_difference -> { MembershipMailer.deliveries.size } do
      perform_enqueued_jobs(only: MembershipRenewalReminderJob)
      perform_enqueued_jobs(only: MailDelivery::ProcessJob)
    end

    assert_nil membership.reload.renewal_reminder_sent_at
  end

  test "a retry stamps the reminder without sending a second email" do
    mail_templates(:membership_renewal_reminder).update!(active: true, delay_in_days: 10)
    member = create_member(emails: "anybody@doe.com")

    travel_to "2024-09-01"
    membership = create_membership(renewal_opened_at: "2024-09-01", member: member)

    travel_to "2024-09-11"
    MailDelivery.deliver!(
      member: member,
      mailable: membership,
      action: "renewal_reminder",
      recipients: [ "anybody@doe.com" ])
    clear_enqueued_jobs
    clear_performed_jobs
    basket_updated_at = membership.baskets.maximum(:updated_at)

    assert_no_difference -> { MailDelivery.count } do
      assert_no_difference -> { MembershipMailer.deliveries.size } do
        MembershipRenewalReminderJob.perform_later(membership)
        perform_enqueued_jobs(only: MembershipRenewalReminderJob)
        perform_enqueued_jobs(only: MailDelivery::ProcessJob)
      end
    end

    membership.reload
    assert_equal Time.current, membership.renewal_reminder_sent_at
    assert_equal basket_updated_at, membership.baskets.maximum(:updated_at)
  end

  private

  def deliver_reminders
    Notification::MembershipRenewalReminder.notify
    perform_enqueued_jobs(only: MembershipRenewalReminderJob)
    perform_enqueued_jobs(only: MailDelivery::ProcessJob)
  end

  def capture_sql
    queries = []
    callback = ->(*, payload) { queries << payload[:sql] }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    queries
  end
end
