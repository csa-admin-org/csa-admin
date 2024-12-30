# frozen_string_literal: true

require "test_helper"

class MemberMailerTest < ActionMailer::TestCase
  test "activated_email" do
    travel_to "2024-01-01"
    template = mail_template(:member_activated)
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
  end

  test "validated_email" do
    template = mail_template(:member_validated)
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
    assert_includes body, "Waiting list position: <strong>1</strong>"
    assert_includes body, "Access my member page"
    assert_includes body, "https://members.acme.test"
  end
end
