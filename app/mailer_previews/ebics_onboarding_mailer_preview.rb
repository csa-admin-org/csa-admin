# frozen_string_literal: true

class EBICSOnboardingMailerPreview < ActionMailer::Preview
  def setup_submitted_notification_email
    EBICSOnboardingMailer
      .with(connection: ebics_connection)
      .setup_submitted_notification_email
  end

  def support_needed_notification_email
    EBICSOnboardingMailer
      .with(connection: ebics_connection(
        state: "errored",
        health_status: "errored",
        onboarding_state: "errored",
        last_error_class: "Billing::EBICS::UnsupportedOperation",
        last_error_message: "EBICS onboarding failed during submit_hia"))
      .support_needed_notification_email
  end

  def finalized_notification_email
    EBICSOnboardingMailer
      .with(connection: ebics_connection(
        state: "ready",
        active: true,
        health_status: "healthy",
        onboarding_state: "finalized"))
      .finalized_notification_email
  end

  private

  def ebics_connection(state: "waiting_for_bank", active: false, health_status: "unknown", onboarding_state: "waiting_for_bank", last_error_class: nil, last_error_message: nil)
    BankConnection.new(
      id: 42,
      provider: "ebics",
      name: "EBICS Bank",
      active: active,
      state: state,
      health_status: health_status,
      last_error_class: last_error_class,
      last_error_message: last_error_message,
      credentials: ebics_credentials,
      settings: { "protocol" => "H005" },
      status_details: ebics_status_details(onboarding_state))
  end

  def ebics_credentials
    {
      "url" => "https://ebics.example.test",
      "host_id" => "PREVIEW_HOSTID",
      "client_id" => "PREVIEW_CLIENTID",
      "participant_id" => "PREVIEW_PARTICIPANTID",
      "secret" => "PREVIEW_SECRET",
      "keys" => "PREVIEW PRIVATE KEY MATERIAL"
    }
  end

  def ebics_status_details(state)
    {
      "onboarding" => {
        "state" => state,
        "target_bits" => 4096,
        "initiated_at" => 1.hour.ago.iso8601,
        "initiated_by_admin_id" => 1,
        "initiated_by_admin_email" => "admin@csa-admin.org",
        "ini_submitted_at" => 58.minutes.ago.iso8601,
        "hia_submitted_at" => 57.minutes.ago.iso8601,
        "finalized_at" => (5.minutes.ago.iso8601 if state == "finalized"),
        "last_finalization_check_at" => (5.minutes.ago.iso8601 if state == "finalized"),
        "last_finalization_status" => ("finalized" if state == "finalized")
      }.compact
    }
  end
end
