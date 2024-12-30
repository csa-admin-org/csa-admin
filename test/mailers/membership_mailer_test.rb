# frozen_string_literal: true

require "test_helper"

class MembershipMailerTest < ActionMailer::TestCase
  test "initial_basket_email" do
    travel_to "2024-01-01"
    template = mail_template(:membership_initial_basket)
    membership = memberships(:john)
    basket = membership.baskets.first

    mail = MembershipMailer.with(
      template: template,
      basket: basket,
    ).initial_basket_email

    assert_equal "First basket!", mail.subject
    assert_equal [ "john@doe.com" ], mail.to
    assert_equal "membership-initial-basket", mail.tag
    assert_includes mail.body.to_s, "https://members.acme.test"
    assert_equal "Acme <info@acme.test>", mail[:from].decoded
    assert_equal "outbound", mail[:message_stream].to_s
  end

  test "final_basket_email" do
    travel_to "2024-01-01"
    template = mail_template(:membership_final_basket)
    membership = memberships(:john)
    basket = membership.baskets.last

    mail = MembershipMailer.with(
      template: template,
      basket: basket,
    ).final_basket_email

    assert_equal "Last basket!", mail.subject
    assert_equal [ "john@doe.com" ], mail.to
    assert_equal "membership-final-basket", mail.tag
    assert_includes mail.body.to_s, "https://members.acme.test"
    assert_equal "Acme <info@acme.test>", mail[:from].decoded
    assert_equal "outbound", mail[:message_stream].to_s
  end

  test "first_basket_email" do
    travel_to "2024-01-01"
    template = mail_template(:membership_first_basket)
    membership = memberships(:john)
    basket = membership.baskets.first

    mail = MembershipMailer.with(
      template: template,
      basket: basket,
    ).first_basket_email

    assert_equal "First basket of the year!", mail.subject
    assert_equal [ "john@doe.com" ], mail.to
    assert_equal "membership-first-basket", mail.tag
    assert_includes mail.body.to_s, "https://members.acme.test"
    assert_equal "Acme <info@acme.test>", mail[:from].decoded
    assert_equal "outbound", mail[:message_stream].to_s
  end

  test "last_basket_email" do
    travel_to "2024-01-01"
    template = mail_template(:membership_last_basket)
    membership = memberships(:john)
    basket = membership.baskets.last

    mail = MembershipMailer.with(
      template: template,
      basket: basket,
    ).last_basket_email

    assert_equal "Last basket of the year!", mail.subject
    assert_equal [ "john@doe.com" ], mail.to
    assert_equal "membership-last-basket", mail.tag
    assert_includes mail.body.to_s, "https://members.acme.test"
    assert_equal "Acme <info@acme.test>", mail[:from].decoded
    assert_equal "outbound", mail[:message_stream].to_s
  end

  test "last_trial_basket_email" do
    travel_to "2024-01-01"
    template = mail_template(:membership_last_trial_basket)
    membership = memberships(:john)
    basket = membership.baskets.first

    mail = MembershipMailer.with(
      template: template,
      basket: basket,
    ).last_trial_basket_email

    assert_equal "Last trial basket!", mail.subject
    assert_equal [ "john@doe.com" ], mail.to
    assert_equal "membership-last-trial-basket", mail.tag
    assert_includes mail.body.to_s, "It's the day of your last trial basket.."
    assert_includes mail.body.to_s, "https://members.acme.test"
    assert_equal "Acme <info@acme.test>", mail[:from].decoded
    assert_equal "outbound", mail[:message_stream].to_s
  end

  test "renewal_email" do
    travel_to "2024-01-01"
    template = mail_template(:membership_renewal)
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
    template = mail_template(:membership_renewal_reminder)
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
end
