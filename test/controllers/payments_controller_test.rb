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

  test "new payment skips search on a locked member and keeps the contextual select" do
    login admins(:super)
    invoice = invoices(:other_closed)

    get new_payment_path(invoice_id: invoice.id)

    assert_response :success
    assert_select "select[name='payment[member_id]'][disabled]"
    assert_select "select[name='payment[member_id]'][data-controller*='searchable-select']", count: 0
    assert_select "input[type=hidden][name='payment[member_id]'][value='#{invoice.member_id}']"

    get new_payment_path, headers: { "HTTP_REFERER" => "#{payments_url}?q[invoice_id_eq]=#{invoice.id}" }

    assert_response :success
    assert_select "select[name='payment[member_id]'][data-controller='searchable-select'][data-payment-form-target='member'][data-action='payment-form#clearInvoice']"
    assert_select "input[type=hidden][name='payment[invoice_id]'][value='#{invoice.id}']"
  end

  test "payments sidebar shows active bank connection health and settings link" do
    BankConnection.create!(
      provider: "ebics",
      active: true,
      state: "ready",
      health_status: "healthy",
      credentials: synthetic_ebics_credentials,
      settings: h005_payment_settings)
    login admins(:super)

    get payments_path

    assert_response :success
    assert_includes response.body, organization_path(anchor: "bank_connection")
    assert_includes response.body, I18n.t("active_admin.resources.organization.bank_connection.health_status.healthy", locale: admins(:super).language)
    assert_includes response.body, "data-status=\"healthy\""
    assert_not_includes response.body, "<th>#{I18n.t("active_admin.resources.organization.bank_connection.health", locale: admins(:super).language)}</th>"
  end

  private

  def h005_payment_settings
    {
      "protocol" => "H005",
      "downloads" => {
        "payments" => {
          "mode" => "btf",
          "btf" => Billing::EBICS::Btf::Presets.camt054(service_name: "REP", scope: "CH", version: "04")
        }
      }
    }
  end

  def login(admin)
    session = Session.create!(
      admin_email: admin.email,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
  end
end
