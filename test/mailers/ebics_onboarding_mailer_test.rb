# frozen_string_literal: true

require "test_helper"

class EBICSOnboardingMailerTest < ActionMailer::TestCase
  setup do
    BankConnection.delete_all
    org(country_code: "CH")
  end



  test "setup_submitted_notification_email sends sanitized support context to ultra admin" do
    connection = onboarding_connection

    mail = EBICSOnboardingMailer
      .with(connection: connection)
      .setup_submitted_notification_email

    assert_equal [ admins(:ultra).email ], mail.to
    assert_equal [ admins(:super).email ], mail.reply_to
    assert_equal "[EBICS] Setup submitted for Acme", mail.subject
    assert_equal "ebics-onboarding-setup-submitted-notification", mail.tag
    body = mail.body.decoded
    assert_includes body, "EBICS onboarding setup was submitted successfully."
    assert_includes body, '"tenant": "acme"'
    assert_includes body, '"bank_connection_id": %d' % connection.id
    assert_sanitized body
  end

  test "support_needed_notification_email sends sanitized failure context to ultra admin" do
    connection = onboarding_connection(
      state: "errored",
      health_status: "errored",
      last_error_class: "Billing::EBICS::UnsupportedOperation",
      last_error_message: "EBICS onboarding failed during submit_hia",
      onboarding_state: "errored")

    mail = EBICSOnboardingMailer
      .with(connection: connection)
      .support_needed_notification_email

    assert_equal [ admins(:ultra).email ], mail.to
    assert_equal "[EBICS] Setup needs support for Acme", mail.subject
    body = mail.body.decoded
    assert_includes body, "EBICS onboarding setup needs support."
    assert_includes body, "EBICS onboarding failed during submit_hia"
    assert_sanitized body
  end

  test "finalized_notification_email sends sanitized completion context to ultra admin" do
    connection = onboarding_connection(
      active: true,
      state: "ready",
      health_status: "healthy",
      onboarding_state: "finalized",
      finalized_at: "2026-07-07T10:30:00Z")

    mail = EBICSOnboardingMailer
      .with(connection: connection)
      .finalized_notification_email

    assert_equal [ admins(:ultra).email ], mail.to
    assert_equal "[EBICS] Setup finalized for Acme", mail.subject
    body = mail.body.decoded
    assert_includes body, "EBICS onboarding setup was finalized successfully."
    assert_includes body, '"onboarding_state": "finalized"'
    assert_sanitized body
  end

  private

  def onboarding_connection(active: false, state: "waiting_for_bank", health_status: "unknown", last_error_class: nil, last_error_message: nil, onboarding_state: "waiting_for_bank", finalized_at: nil)
    BankConnection.create!(
      provider: "ebics",
      name: "HOSTID",
      active: active,
      state: state,
      health_status: health_status,
      last_error_class: last_error_class,
      last_error_message: last_error_message,
      credentials: {
        "url" => "https://ebics.example.test",
        "host_id" => "HOSTID",
        "client_id" => "CLIENTID",
        "participant_id" => "PARTICIPANTID",
        "secret" => "VERY_SECRET_EBICS_SETUP_SECRET",
        "keys" => "-----BEGIN PRIVATE KEY-----\nPRIVATE KEY MATERIAL\n-----END PRIVATE KEY-----"
      },
      settings: { "protocol" => "H005" },
      status_details: {
        "onboarding" => {
          "state" => onboarding_state,
          "target_bits" => 4096,
          "initiated_at" => "2026-07-07T10:00:00Z",
          "initiated_by_admin_id" => admins(:super).id,
          "initiated_by_admin_email" => admins(:super).email,
          "ini_submitted_at" => "2026-07-07T10:01:00Z",
          "hia_submitted_at" => "2026-07-07T10:02:00Z",
          "finalized_at" => finalized_at,
          "finalization_return_code" => "091005",
          "finalization_report_text" => "Bank response for CLIENTID and PARTICIPANTID"
        }.compact
      })
  end

  def assert_sanitized(body)
    assert_not_includes body, "VERY_SECRET_EBICS_SETUP_SECRET"
    assert_not_includes body, "PRIVATE KEY MATERIAL"
    assert_not_includes body, "PARTICIPANTID"
    assert_not_includes body, "CLIENTID"
    assert_not_includes body, "Bank response for"
  end
end
