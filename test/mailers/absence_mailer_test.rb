# frozen_string_literal: true

require "test_helper"

class AbsenceMailerTest < ActionMailer::TestCase
  test "created_email" do
    travel_to "2024-01-01"
    template = mail_templates(:absence_created)
    absence = absences(:jane_thursday_5)

    mail = AbsenceMailer.with(
      template: template,
      absence: absence,
    ).created_email

    assert_equal "Absence confirmation", mail.subject
    assert_equal [ "jane@doe.com" ], mail.to
    assert_equal "absence-created", mail.tag
    assert_equal "Acme <info@acme.test>", mail[:from].decoded
    assert_equal "outbound", mail[:message_stream].to_s

    body = mail.body.to_s
    assert_includes body, "Your absence has been successfully registered"
    assert_includes body, "Access my member page"
    assert_includes body, "https://members.acme.test/absences"
  end

  test "baskets_shifted_email" do
    travel_to "2024-01-01"
    template = mail_templates(:absence_baskets_shifted)
    absence = absences(:jane_thursday_5)
    BasketShift.create!(
      absence: absence,
      source_basket: baskets(:jane_5),
      target_basket: baskets(:jane_6))

    mail = AbsenceMailer.with(
      template: template,
      absence: absence,
    ).baskets_shifted_email

    assert_equal "Basket(s) shifted", mail.subject
    assert_equal [ "jane@doe.com" ], mail.to
    assert_equal "absence-baskets-shifted", mail.tag
    assert_equal "Acme <info@acme.test>", mail[:from].decoded
    assert_equal "outbound", mail[:message_stream].to_s

    body = mail.body.to_s
    assert_includes body, "Your basket shifts during your absence have been successfully registered"
    assert_includes body, "Access my member page"
    assert_includes body, "https://members.acme.test"
  end
end
