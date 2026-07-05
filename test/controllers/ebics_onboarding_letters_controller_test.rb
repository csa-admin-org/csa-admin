# frozen_string_literal: true

require "test_helper"
require "openssl"

class EbicsOnboardingLettersControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "admin.acme.test"
    BankConnection.delete_all
  end

  test "serves initialization letter PDF with no-store headers" do
    initialized_connection
    login(admins(:ultra))

    get ebics_initialization_letter_path(locale: "fr")

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_no_store_download_headers
    assert_not_includes response.body, "PRIVATE KEY"
  end

  test "redirects when no EBICS connection is waiting for an initialization letter" do
    login(admins(:ultra))

    get ebics_initialization_letter_path

    assert_redirected_to organization_path
    assert_equal I18n.t("ebics.initialization_letter.unavailable"), flash[:notice]
  end

  test "redirects when an initializing EBICS connection has no onboarding credentials" do
    BankConnection.create!(
      provider: "ebics",
      name: "Stale EBICS setup",
      active: false,
      state: "initializing",
      health_status: "unknown")
    login(admins(:ultra))

    get ebics_initialization_letter_path

    assert_redirected_to organization_path
    assert_equal I18n.t("ebics.initialization_letter.unavailable"), flash[:notice]
  end

  private

  def login(admin)
    session = Session.create!(
      admin_email: admin.email,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
  end

  def initialized_connection
    org(country_code: "CH")
    Billing::EBICS::Onboarding.new(
      tenant: "acme",
      now: Time.zone.parse("2026-07-05 10:00"),
      key_generator: ->(_bits) { OpenSSL::PKey::RSA.generate(2048) }).initialize_connection!(
        url: "https://ebics.example.test",
        host_id: "HOSTID",
        partner_id: "PARTNERID",
        user_id: "USERID",
        name: "Test Bank",
        target_bits: 2048)
    BankConnection.last
  end
end
