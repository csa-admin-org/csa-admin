# frozen_string_literal: true

require "test_helper"

class AdminMailerEBICSOnboardingTest < ActionMailer::TestCase
  setup do
    BankConnection.delete_all
    org(country_code: "CH")
  end

  test "ebics_setup_submitted_email sends initialization letter instructions" do
    admin = admins(:super)
    connection = onboarding_connection

    mail = AdminMailer
      .with(admin: admin, connection: connection)
      .ebics_setup_submitted_email

    assert_equal [ admin.email ], mail.to
    assert_equal "EBICS setup started", mail.subject
    assert_equal "admin-ebics-setup-submitted", mail.tag
    assert_equal "Acme <info@acme.test>", mail[:from].decoded
    body = mail.body.to_s
    assert_includes body, "Hello Acme Super Admin,"
    assert_includes body, "The EBICS setup was submitted successfully."
    assert_includes body, "https://admin.acme.test/ebics_initialization_letter"
    assert_includes body, "https://admin.acme.test/settings#bank_connection"
    assert_includes body, "Review bank connection settings"
    assert_sanitized body
  end

  test "ebics_setup_finalized_email tells initiating admin setup is active" do
    admin = admins(:super)
    connection = onboarding_connection(active: true, state: "ready", onboarding_state: "finalized")

    mail = AdminMailer
      .with(admin: admin, connection: connection)
      .ebics_setup_finalized_email

    assert_equal [ admin.email ], mail.to
    assert_equal "EBICS setup finalized", mail.subject
    assert_equal "admin-ebics-setup-finalized", mail.tag
    body = mail.body.to_s
    assert_includes body, "Good news: the bank has activated the EBICS connection."
    assert_includes body, "The EBICS connection is active."
    assert_includes body, "Payment automation health is shown in the bank connection settings."
    assert_includes body, "https://admin.acme.test/settings#bank_connection"
    assert_sanitized body
  end

  test "EBICS setup emails use the standard French admin greeting" do
    admin = admins(:super)
    admin.update!(language: "fr")
    connection = onboarding_connection

    mails = [
      AdminMailer.with(admin: admin, connection: connection).ebics_setup_submitted_email,
      AdminMailer.with(admin: admin, connection: connection).ebics_setup_finalized_email
    ]

    mails.each do |mail|
      assert_includes mail.body.to_s, "Salut Acme Super Admin,"
      assert_not_includes mail.body.to_s, "Bonjour Acme Super Admin,"
    end
  end

  private

  def onboarding_connection(active: false, state: "waiting_for_bank", onboarding_state: "waiting_for_bank")
    connection = BankConnection.new(
      provider: "ebics",
      name: "HOSTID",
      active: active,
      state: state,
      health_status: active ? "healthy" : "unknown",
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
          "hia_submitted_at" => "2026-07-07T10:02:00Z"
        }
      })
    connection.save!(validate: !active)
    connection
  end

  def assert_sanitized(body)
    assert_not_includes body, "VERY_SECRET_EBICS_SETUP_SECRET"
    assert_not_includes body, "PRIVATE KEY MATERIAL"
    assert_not_includes body, "PARTICIPANTID"
    assert_not_includes body, "CLIENTID"
  end
end
