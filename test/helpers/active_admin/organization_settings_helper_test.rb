# frozen_string_literal: true

require "test_helper"

class ActiveAdmin::OrganizationSettingsHelperTest < ActionView::TestCase
  include ActiveAdmin::OrganizationSettingsHelper

  setup do
    BankConnection.delete_all
  end

  test "bank connection section is an always enabled core setting" do
    section = organization_setting_section(:bank_connection)

    assert_equal "bank_connection", section.fetch(:key)
    assert_equal :core, section.fetch(:kind)
    assert organization_setting_section_enabled?(section)
    assert organization_setting_section_available?(section)
    assert_not organization_setting_section_editable?(section)
  end

  test "active EBICS connection display exposes protocol and compact health only" do
    org(country_code: "CH", features: [], sepa_creditor_identifier: nil)
    connection = BankConnection.create!(
      provider: "ebics",
      active: true,
      state: "ready",
      health_status: "healthy",
      credentials: synthetic_ebics_credentials,
      settings: h005_payment_settings,
      status_details: {
        "last_capabilities_check" => {
          "status" => "healthy",
          "checked_at" => "2026-07-05T08:30:00Z"
        }
      },
      last_no_data_at: Time.zone.parse("2026-07-05 08:00"))

    provider = organization_settings_bank_connection_provider(connection)

    assert_equal connection, organization_settings_bank_connection
    assert_equal "EBICS 3.0/H005 (2048-bits)", provider
    assert_includes organization_settings_bank_connection_health(connection), "Healthy"
    assert_includes organization_settings_bank_connection_health(connection), "data-status=\"healthy\""
    assert_not organization_settings_bank_connection_payment_automation_warning?(connection)
    assert_equal I18n.l(Date.new(2026, 7, 5), format: :short), organization_settings_bank_connection_last_import(connection)
    assert_not_includes provider, "secret"
    assert_not_includes provider, "PRIVATE KEY"
    assert_not_includes provider, "BTD"
    assert_not_includes provider, "Participant keys"
  end

  test "active EBICS card warns when payment download is missing" do
    connection = BankConnection.new(
      provider: "ebics",
      active: true,
      state: "ready",
      health_status: "healthy",
      credentials: synthetic_ebics_credentials,
      settings: { "protocol" => "H005" })
    connection.save!(validate: false)

    assert organization_settings_bank_connection_payment_automation_warning?(connection)
    assert_includes organization_settings_bank_connection_payment_automation(connection),
      "Payment download is not fully configured yet."
  end

  test "active EBICS card warns while payment automation verification is pending" do
    org(country_code: "CH", features: [], sepa_creditor_identifier: nil)
    connection = BankConnection.create!(
      provider: "ebics",
      active: true,
      state: "ready",
      health_status: "healthy",
      credentials: synthetic_ebics_credentials,
      settings: h005_payment_settings)

    assert organization_settings_bank_connection_payment_automation_warning?(connection)
    assert_includes organization_settings_bank_connection_payment_automation(connection),
      "Payment automation verification is pending."
  end

  test "active EBICS card warns when SEPA upload configuration is missing" do
    german_org(sepa_creditor_identifier: "DE98ZZZ09999999999")
    connection = BankConnection.new(
      provider: "ebics",
      active: true,
      state: "ready",
      health_status: "healthy",
      credentials: synthetic_ebics_credentials,
      settings: h005_payment_settings,
      status_details: {
        "last_capabilities_check" => {
          "status" => "healthy",
          "checked_at" => "2026-07-05T08:30:00Z"
        }
      })
    connection.save!(validate: false)

    assert organization_settings_bank_connection_payment_automation_warning?(connection)
    assert_includes organization_settings_bank_connection_payment_automation(connection),
      "Direct debit upload is not fully configured yet."
  end

  test "active EBICS card warns when payment automation needs review" do
    org(country_code: "CH", features: [], sepa_creditor_identifier: nil)
    connection = BankConnection.create!(
      provider: "ebics",
      active: true,
      state: "ready",
      health_status: "healthy",
      credentials: synthetic_ebics_credentials,
      settings: h005_payment_settings,
      status_details: {
        "last_capabilities_check" => {
          "status" => "warning",
          "checked_at" => "2026-07-05T08:30:00Z"
        }
      })

    assert organization_settings_bank_connection_payment_automation_warning?(connection)
    assert_includes organization_settings_bank_connection_payment_automation(connection),
      "Payment automation needs review."
  end

  test "active BAS connection display exposes contract and account ids" do
    connection = BankConnection.create!(
      provider: "bas",
      active: true,
      state: "ready",
      health_status: "healthy",
      credentials: {
        account_number: "389.090.100.04",
        contract_number: "IB1601431",
        contract_password: "secret"
      })

    assert_equal "BAS IB1601431 / 389.090.100.04", organization_settings_bank_connection_provider(connection)
    assert_not_includes organization_settings_bank_connection_provider(connection), "secret"
  end

  test "active bunq connection display exposes the monetary account id" do
    connection = BankConnection.create!(
      provider: "bunq",
      active: true,
      state: "ready",
      health_status: "healthy",
      credentials: {
        monetary_account_id: "123456",
        api_key: "secret"
      })

    assert_equal "Bunq 123456", organization_settings_bank_connection_provider(connection)
    assert_not_includes organization_settings_bank_connection_provider(connection), "secret"
  end

  test "healthy no-data import stays healthy and shows only the date" do
    connection = BankConnection.create!(
      provider: "bas",
      active: true,
      state: "ready",
      health_status: "healthy",
      credentials: { account_number: "IB1601431", contract_password: "secret" },
      last_no_data_at: Time.zone.parse("2026-07-05 08:00"))

    assert_includes organization_settings_bank_connection_health(connection), "Healthy"
    assert_equal I18n.l(Date.new(2026, 7, 5), format: :short), organization_settings_bank_connection_last_import(connection)
    assert_not_includes organization_settings_bank_connection_last_import(connection), "data"
  end

  test "latest error display does not expose raw provider messages" do
    healthy = BankConnection.new(provider: "bas", health_status: "healthy", last_error_message: "hidden")
    capability_warning = BankConnection.new(
      provider: "ebics",
      health_status: "warning",
      last_error_class: "UnexpectedEBICSCapability")
    errored = BankConnection.new(
      provider: "bas",
      health_status: "errored",
      last_error_class: "Billing::BAS::AuthenticationError",
      last_error_message: "Login issue with secret token")

    assert_not organization_settings_bank_connection_error?(healthy)
    assert_not organization_settings_bank_connection_error?(capability_warning)
    assert organization_settings_bank_connection_error?(errored)
    assert_includes organization_settings_bank_connection_error(healthy), "Not configured"
    assert_equal "Authentication error", organization_settings_bank_connection_error(errored)
    assert_not_includes organization_settings_bank_connection_error(errored), "secret"
  end

  test "ongoing EBICS setup is selected when no active connection exists" do
    connection = BankConnection.create!(
      provider: "ebics",
      name: "HOSTID",
      active: false,
      state: "waiting_for_bank",
      health_status: "unknown",
      status_details: {
        "onboarding" => {
          "state" => "waiting_for_bank",
          "ini_submitted_at" => "2026-07-05T08:00:00Z",
          "hia_submitted_at" => "2026-07-05T08:01:00Z"
        }
      })

    assert_equal connection, organization_settings_bank_connection
    assert organization_settings_bank_connection_setup?(connection)
    assert_includes organization_settings_bank_connection_onboarding_state(connection), "Waiting for bank"
    assert_includes organization_settings_bank_connection_onboarding_state(connection), "data-status=\"waiting\""

    connection.update!(status_details: { "onboarding" => { "state" => "ini_submitted" } })
    assert_includes organization_settings_bank_connection_onboarding_state(connection), "Initializing"
    assert_not_includes organization_settings_bank_connection_onboarding_state(connection), "INI submitted"
  end

  test "initialization letter link requires waiting for bank and submitted setup orders" do
    connection = BankConnection.create!(
      provider: "ebics",
      name: "HOSTID",
      active: false,
      state: "waiting_for_bank",
      health_status: "unknown",
      credentials: synthetic_ebics_onboarding_credentials,
      settings: { "protocol" => "H005" },
      status_details: {
        "onboarding" => {
          "state" => "waiting_for_bank",
          "target_bits" => 2048,
          "ini_submitted_at" => "2026-07-05T08:00:00Z",
          "hia_submitted_at" => "2026-07-05T08:01:00Z"
        }
      })

    assert organization_settings_bank_connection_letter_available?(connection)

    details = connection.status_details.to_h.deep_stringify_keys
    details["onboarding"] = details.fetch("onboarding").except("hia_submitted_at")
    connection.update!(status_details: details)
    assert_not organization_settings_bank_connection_letter_available?(connection)

    details["onboarding"] = details.fetch("onboarding").merge("hia_submitted_at" => "2026-07-05T08:01:00Z")
    connection.update!(state: "initializing", status_details: details)
    assert_not organization_settings_bank_connection_letter_available?(connection)
  end

  private

  def synthetic_ebics_onboarding_credentials
    synthetic_ebics_credentials.except("HOSTID.X002", "HOSTID.E002")
  end

  def h005_payment_settings
    {
      "protocol" => "H005",
      "downloads" => {
        "payments" => {
          "mode" => "btf",
          "btf" => Billing::EBICS::Btf::Presets.payment_download(country_code: "CH")
        }
      }
    }
  end
end
