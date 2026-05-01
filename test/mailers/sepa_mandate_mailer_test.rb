# frozen_string_literal: true

require "test_helper"

class SEPAMandateMailerTest < ActionMailer::TestCase
  test "confirmation_email" do
    german_org(sepa_creditor_identifier: "DE98ZZZ09999999999")
    template = mail_templates(:sepa_mandate_confirmation)
    template.update!(active: true)

    member = members(:anna)
    member.update!(language: "de", country_code: "DE")
    mandate = member.sepa_mandates.create!(
      iban: "DE21500500009876543210",
      umr: "42",
      signed_on: Date.parse("2024-06-15"),
      sepa_mandate_accepted: "1",
      source: "self-service")

    mail = SEPAMandateMailer.with(
      template: template,
      sepa_mandate: mandate
    ).confirmation_email

    assert_equal "Bestätigung des SEPA-Mandats", mail.subject
    assert_equal [ "anna@doe.com" ], mail.to
    assert_equal "sepa-mandate-confirmation", mail.tag

    body = mail.body.to_s
    assert_includes body, "Mandatsreferenz:"
    assert_includes body, "42"
    assert_includes body, "DE21 •••• •••• 3210"
  end
end
