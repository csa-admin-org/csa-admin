# frozen_string_literal: true

require "test_helper"

class PaymentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "admin.acme.test"
    BankConnection.delete_all
  end

  test "payments sidebar links to bank connection settings when automatic processing is missing" do
    login admins(:super)

    get payments_path

    assert_response :success
    assert_includes response.body, organization_path(anchor: "bank_connection")
    assert_includes response.body, I18n.t(
      "active_admin.shared.sidebar_section.no_automatic_payments_processing_warning_text_html",
      locale: admins(:super).language,
      settings_url: organization_path(anchor: "bank_connection"))
    assert_not_includes response.body, "data-status=\"unconfigured\""
    assert_not_includes response.body, "<th>#{I18n.t("active_admin.resources.organization.bank_connection.health", locale: admins(:super).language)}</th>"
  end

  test "payments sidebar shows active bank connection health and settings link" do
    BankConnection.create!(
      provider: "ebics",
      active: true,
      state: "ready",
      health_status: "healthy",
      credentials: synthetic_ebics_credentials,
      settings: { "protocol" => "H005" })
    login admins(:super)

    get payments_path

    assert_response :success
    assert_includes response.body, organization_path(anchor: "bank_connection")
    assert_includes response.body, I18n.t("active_admin.resources.organization.bank_connection.health_status.healthy", locale: admins(:super).language)
    assert_includes response.body, "data-status=\"healthy\""
    assert_not_includes response.body, "<th>#{I18n.t("active_admin.resources.organization.bank_connection.health", locale: admins(:super).language)}</th>"
  end

  private

  def login(admin)
    session = Session.create!(
      admin_email: admin.email,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
  end
end
