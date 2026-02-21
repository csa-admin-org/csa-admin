# frozen_string_literal: true

require "test_helper"

class MembershipMailerTest < ActionMailer::TestCase
  test "renewal_email" do
    travel_to "2024-01-01"
    template = mail_templates(:membership_renewal)
    membership = memberships(:john)

    mail = MembershipMailer.with(
      template: template,
      membership: membership,
    ).renewal_email

    assert_equal "Renew your membership", mail.subject
    assert_equal [ "john@doe.com" ], mail.to
    assert_equal "membership-renewal", mail.tag
    assert_includes mail.body.to_s, "Access the renewal form"
    assert_includes mail.body.to_s, "https://members.acme.test/memberships#renewal"
    assert_equal "Acme <info@acme.test>", mail[:from].decoded
    assert_equal "outbound", mail[:message_stream].to_s
  end

  test "renewal_reminder_email" do
    travel_to "2024-01-01"
    template = mail_templates(:membership_renewal_reminder)
    membership = memberships(:john)

    mail = MembershipMailer.with(
      template: template,
      membership: membership,
    ).renewal_reminder_email

    assert_equal "Renew your membership (reminder)", mail.subject
    assert_equal [ "john@doe.com" ], mail.to
    assert_equal "membership-renewal-reminder", mail.tag
    assert_includes mail.body.to_s, "Access the renewal form"
    assert_includes mail.body.to_s, "https://members.acme.test/memberships#renewal"
    assert_equal "Acme <info@acme.test>", mail[:from].decoded
    assert_equal "outbound", mail[:message_stream].to_s
  end

  test "absence_included_reminder_email" do
    travel_to "2024-01-01"
    org(
      trial_baskets_count: 0,
      absences_billed: true,
      absences_included_mode: "provisional_absence"
    )
    template = mail_templates(:absence_included_reminder)
    membership = memberships(:john)
    membership.update!(absences_included_annually: 2)

    mail = MembershipMailer.with(
      template: template,
      membership: membership,
    ).absence_included_reminder_email

    assert_equal "Included absences reminder", mail.subject
    assert_equal [ "john@doe.com" ], mail.to
    assert_equal "absence-included-reminder", mail.tag
    assert_equal "Acme <info@acme.test>", mail[:from].decoded
    assert_equal "outbound", mail[:message_stream].to_s

    body = mail.body.to_s
    assert_includes body, "Your membership includes"
  end
end
