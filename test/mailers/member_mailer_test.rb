# frozen_string_literal: true

require "test_helper"

class MemberMailerTest < ActionMailer::TestCase
  test "activated_email" do
    travel_to "2024-01-01"
    template = mail_templates(:member_activated)
    membership = memberships(:jane)

    mail = MemberMailer.with(
      template: template,
      member: membership.member,
    ).activated_email

    assert_equal "Welcome!", mail.subject
    assert_equal [ "jane@doe.com" ], mail.to
    assert_equal "member-activated", mail.tag
    assert_equal "Acme <info@acme.test>", mail[:from].decoded
    assert_equal "outbound", mail[:message_stream].to_s

    body = mail.body.to_s
    assert_includes body, "<strong>Depot:</strong> Bakery"
    assert_includes body, "<strong>Basket size:</strong> Large"
    assert_includes body, "<strong>Complements:</strong> Bread"
    assert_includes body, "Access my member page"
    assert_includes body, "https://members.acme.test"
    refute_includes body, "Sign SEPA mandate"
    refute_includes body, "href=\"\""
  end

  test "shop_depot_activated_email" do
    travel_to "2024-01-01"
    template = mail_templates(:member_shop_depot_activated)
    member = members(:mary)
    member.update_columns(shop_depot_id: depots(:farm).id)

    mail = MemberMailer.with(
      template: template,
      member: member
    ).shop_depot_activated_email

    assert_equal "Your shop access is active!", mail.subject
    assert_equal [ "mary@doe.com" ], mail.to
    assert_equal "member-shop-depot-activated", mail.tag
    assert_equal "Acme <info@acme.test>", mail[:from].decoded
    assert_equal "outbound", mail[:message_stream].to_s

    body = mail.body.to_s
    assert_includes body, "Your shop access is now active."
    assert_includes body, "<strong>Pickup depot:</strong> Our farm"
    assert_includes body, "Access my member page"
    assert_includes body, "https://members.acme.test"
  end

  test "validated_email" do
    template = mail_templates(:member_validated)
    member = members(:john)

    mail = MemberMailer.with(
      template: template,
      member: member
    ).validated_email

    assert_equal "Registration validated!", mail.subject
    assert_equal [ "john@doe.com" ], mail.to
    assert_equal "member-validated", mail.tag
    assert_equal "Acme <info@acme.test>", mail[:from].decoded
    assert_equal "outbound", mail[:message_stream].to_s

    body = mail.body.to_s
    refute_includes body, "Waiting list position:"
    assert_includes body, "Access my member page"
    assert_includes body, "https://members.acme.test"
    refute_includes body, "Sign SEPA mandate"
    refute_includes body, "href=\"\""
  end

  test "validated_email includes waiting list position for waiting member" do
    template = mail_templates(:member_validated)
    member = members(:aria)

    mail = MemberMailer.with(
      template: template,
      member: member
    ).validated_email

    assert_includes mail.body.to_s, "Waiting list position: <strong>1</strong>"
  end

  test "activated_email escapes a hostile member name" do
    travel_to "2024-01-01"
    template = mail_templates(:member_activated)
    template.update!(content: "<p>Hello {{ member.name }}</p>")
    membership = memberships(:jane)
    membership.member.update_column(:name, %{Jane <img src=x onerror=alert(1)>})

    mail = MemberMailer.with(
      template: template,
      member: membership.member
    ).activated_email

    body = mail.body.to_s
    refute_includes body, "<img src=x"
    assert_includes body, "Hello Jane &lt;img src=x onerror=alert(1)&gt;"
  end
end
