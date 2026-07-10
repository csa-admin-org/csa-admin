# frozen_string_literal: true

require "test_helper"

class EBICSOnboardingMailerPreviewTest < ActionMailer::TestCase
  setup do
    org(country_code: "CH")
    I18n.locale = :en
  end

  test "admin EBICS onboarding previews render" do
    preview = AdminMailerPreview.new

    setup_mail = preview.ebics_setup_submitted_email
    assert_preview_email setup_mail,
      subject: "EBICS setup started",
      to: "admin@csa-admin.org",
      body: [
        "The EBICS setup was submitted successfully.",
        "Download initialization letter",
        "Review bank connection settings"
      ]

    finalized_mail = preview.ebics_setup_finalized_email
    assert_preview_email finalized_mail,
      subject: "EBICS setup finalized",
      to: "admin@csa-admin.org",
      body: [
        "Good news: the bank has activated the EBICS connection.",
        "Payment automation health is shown in the bank connection settings.",
        "Review bank connection settings"
      ]
  end

  test "ultra-admin EBICS onboarding previews render" do
    preview = EBICSOnboardingMailerPreview.new

    submitted_mail = preview.setup_submitted_notification_email
    assert_preview_email submitted_mail,
      subject: "[EBICS] Setup submitted for Acme",
      to: admins(:ultra).email,
      body: [
        "EBICS onboarding setup was submitted successfully.",
        '"tenant": "acme"',
        '"bank_connection_id": 42'
      ]

    support_mail = preview.support_needed_notification_email
    assert_preview_email support_mail,
      subject: "[EBICS] Setup needs support for Acme",
      to: admins(:ultra).email,
      body: [
        "EBICS onboarding setup needs support.",
        "Billing::EBICS::UnsupportedOperation"
      ]

    finalized_mail = preview.finalized_notification_email
    assert_preview_email finalized_mail,
      subject: "[EBICS] Setup finalized for Acme",
      to: admins(:ultra).email,
      body: [
        "EBICS onboarding setup was finalized successfully.",
        '"onboarding_state": "finalized"'
      ]
  end

  private

  def assert_preview_email(mail, subject:, to:, body:)
    assert_equal [ to ], mail.to
    assert_equal subject, mail.subject

    body.each do |text|
      assert_includes mail.body.decoded, text
    end
    assert_sanitized mail.body.decoded
  end

  def assert_sanitized(body)
    assert_not_includes body, "PREVIEW_SECRET"
    assert_not_includes body, "PREVIEW PRIVATE KEY MATERIAL"
    assert_not_includes body, "PREVIEW_CLIENTID"
    assert_not_includes body, "PREVIEW_PARTICIPANTID"
  end
end
