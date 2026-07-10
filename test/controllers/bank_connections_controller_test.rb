# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class BankConnectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "admin.acme.test"
    BankConnection.delete_all
    org(country_code: "CH", sepa_creditor_identifier: nil)
  end

  test "superadmins can open the EBICS setup form" do
    login admins(:super)
    locale = admins(:super).language

    get new_bank_connection_path

    assert_response :success
    assert_select "h2", text: I18n.t("active_admin.resources.bank_connection.ebics_setup.title", locale: locale)
    assert_select "form[action='#{bank_connections_path}']"
    assert_select "input#ebics_setup_url"
    assert_select "input#ebics_setup_host_id"
    assert_select "input#ebics_setup_client_id"
    assert_select "input#ebics_setup_participant_id"
    assert_select "input#ebics_setup_confirmation"
    assert_select "form", text: /#{Regexp.escape(I18n.t("active_admin.resources.bank_connection.ebics_setup.hints.url_html", locale: locale))}/
    assert_select "form", text: /#{Regexp.escape("The bank may call this Client ID, Contract ID, Partner ID, Customer ID, or Vertrags-ID.")}/
    assert_select "form", text: /#{Regexp.escape("The bank may call this Participant ID, User ID, Subscriber ID, or Teilnehmer-ID.")}/
    assert_not_includes response.body, "PRIVATE KEY"
    assert_not_includes response.body, "secret"
  end

  test "regular admins cannot open the EBICS setup form" do
    login admins(:external)

    get new_bank_connection_path

    assert_response :redirect
    assert_not_includes response.body, "ebics_setup_url"
  end

  test "setup instructions show country-specific EBICS requirements" do
    login admins(:super)
    locale = admins(:super).language

    get new_bank_connection_path

    assert_response :success
    assert_select "li", text: I18n.t("active_admin.resources.bank_connection.ebics_setup.bank_access.payment_reports_ch", locale: locale)
    assert_select "li", text: I18n.t("active_admin.resources.bank_connection.ebics_setup.bank_access.payment_reports_de", locale: locale), count: 0
    assert_select "li", text: I18n.t("active_admin.resources.bank_connection.ebics_setup.bank_access.direct_debit_de", locale: locale), count: 0
    assert_select "p.italic", count: 1

    org(country_code: "DE", sepa_creditor_identifier: "DE98ZZZ09999999999")

    get new_bank_connection_path

    assert_response :success
    assert_select "li", text: I18n.t("active_admin.resources.bank_connection.ebics_setup.bank_access.payment_reports_ch", locale: locale), count: 0
    assert_select "li", text: I18n.t("active_admin.resources.bank_connection.ebics_setup.bank_access.payment_reports_de", locale: locale)
    assert_select "li", text: I18n.t("active_admin.resources.bank_connection.ebics_setup.bank_access.direct_debit_de", locale: locale)
    assert_select "p.italic", count: 0
  end

  test "existing active connection blocks setup" do
    BankConnection.create!(
      provider: "bas",
      active: true,
      state: "ready",
      health_status: "healthy",
      credentials: { account_number: "389.090.100.04" })
    login admins(:super)

    get new_bank_connection_path

    assert_redirected_to organization_path(anchor: "bank_connection")
    assert_equal I18n.t("active_admin.resources.bank_connection.ebics_setup.flash.active_connection"), flash[:alert]
  end

  test "ongoing EBICS setup blocks a second setup" do
    BankConnection.create!(
      provider: "ebics",
      name: "HOSTID",
      active: false,
      state: "waiting_for_bank",
      health_status: "unknown")
    login admins(:super)

    get new_bank_connection_path

    assert_redirected_to organization_path(anchor: "bank_connection")
    assert_equal I18n.t("active_admin.resources.bank_connection.ebics_setup.flash.existing_setup"), flash[:alert]
  end

  test "errored EBICS setup blocks a second setup" do
    BankConnection.create!(
      provider: "ebics",
      name: "HOSTID",
      active: false,
      state: "errored",
      health_status: "errored")
    login admins(:super)

    get new_bank_connection_path

    assert_redirected_to organization_path(anchor: "bank_connection")
    assert_equal I18n.t("active_admin.resources.bank_connection.ebics_setup.flash.existing_setup"), flash[:alert]
  end

  test "unsupported countries cannot submit the setup form" do
    france_org
    login admins(:super)

    post bank_connections_path, params: { ebics_setup: valid_setup_params }

    assert_redirected_to organization_path(anchor: "bank_connection")
    assert_equal I18n.t("active_admin.resources.bank_connection.ebics_setup.flash.unsupported_country"), flash[:alert]
    assert_empty BankConnection.all
  end

  test "demo tenants can view but not submit the setup form" do
    login admins(:super)

    Tenant.stub(:demo?, true) do
      get new_bank_connection_path
    end

    assert_response :success
    assert_select "input#ebics_setup_url[disabled]"
    assert_select "input#ebics_setup_host_id[disabled]"
    assert_select "input#ebics_setup_client_id[disabled]"
    assert_select "input#ebics_setup_participant_id[disabled]"
    assert_select "input#ebics_setup_confirmation[disabled]"
    assert_select "button[type='submit'][disabled]", text: I18n.t("active_admin.resources.bank_connection.ebics_setup.submit")
  end

  test "invalid setup input rerenders the form" do
    login admins(:super)

    post bank_connections_path, params: {
      ebics_setup: valid_setup_params.merge(url: "ebics.example.test")
    }

    assert_response :unprocessable_entity
    assert_select "input#ebics_setup_url"
    assert_empty BankConnection.all
  end

  test "create rerenders form when HEV preflight rejects the URL or H005 support" do
    login admins(:super)

    [
      Billing::EBICS::VersionProbe::EndpointError,
      Billing::EBICS::VersionProbe::UnsupportedVersionError
    ].each do |failure_class|
      assert_no_enqueued_emails do
        with_fake_onboarding(fail_at: :initialize, failure_class: failure_class) do
          post bank_connections_path, params: { ebics_setup: valid_setup_params }
        end
      end

      assert_response :unprocessable_entity
      assert_select "li#ebics_setup_url_input p.inline-errors", text: I18n.t("active_admin.resources.bank_connection.ebics_setup.validation.endpoint")
      assert_empty BankConnection.all
    end
  end

  test "create rerenders form when HEV preflight rejects the Host ID" do
    login admins(:super)

    assert_no_enqueued_emails do
      with_fake_onboarding(fail_at: :initialize, failure_class: Billing::EBICS::VersionProbe::HostIDError) do
        post bank_connections_path, params: { ebics_setup: valid_setup_params }
      end
    end

    assert_response :unprocessable_entity
    assert_select "li#ebics_setup_host_id_input p.inline-errors", text: I18n.t("active_admin.resources.bank_connection.ebics_setup.validation.host_id")
    assert_empty BankConnection.all
  end

  test "create rerenders form when endpoint check fails before INI" do
    login admins(:super)

    assert_no_enqueued_emails do
      with_fake_onboarding(
        fail_at: :submit_ini,
        failure_class: "Billing::EBICS::Btf::Transport::HTTPError") do
        post bank_connections_path, params: { ebics_setup: valid_setup_params }
      end
    end

    assert_response :unprocessable_entity
    assert_includes response.body, I18n.t("active_admin.resources.bank_connection.ebics_setup.validation.endpoint")
    assert_includes response.body, I18n.t("active_admin.resources.bank_connection.ebics_setup.validation.retry_or_contact")
    assert_empty BankConnection.all
  end

  test "create rerenders form when bank rejects identifiers before INI" do
    login admins(:super)

    assert_no_enqueued_emails do
      with_fake_onboarding(fail_at: :submit_ini, failure_class: "Billing::EBICS::ClientError") do
        post bank_connections_path, params: { ebics_setup: valid_setup_params }
      end
    end

    assert_response :unprocessable_entity
    assert_select "li#ebics_setup_host_id_input p.inline-errors", count: 0
    assert_select "li#ebics_setup_client_id_input p.inline-errors", text: I18n.t("active_admin.resources.bank_connection.ebics_setup.validation.identifiers")
    assert_select "li#ebics_setup_participant_id_input p.inline-errors", text: I18n.t("active_admin.resources.bank_connection.ebics_setup.validation.identifiers")
    assert_includes response.body, I18n.t("active_admin.resources.bank_connection.ebics_setup.validation.retry_or_contact")
    assert_empty BankConnection.all
  end

  test "create redirects with alert when INI submission fails unexpectedly" do
    login admins(:super)

    assert_enqueued_emails 1 do
      with_fake_onboarding(fail_at: :submit_ini, failure_class: "RuntimeError") do
        post bank_connections_path, params: { ebics_setup: valid_setup_params }
      end
    end

    assert_redirected_to organization_path(anchor: "bank_connection")
    assert_equal I18n.t("active_admin.resources.bank_connection.ebics_setup.flash.alert"), flash[:alert]
    assert_equal "errored", BankConnection.sole.state
    assert_nil BankConnection.sole.status_details.dig("onboarding", "ini_submitted_at")
  end

  test "create redirects with alert when HIA submission fails after INI" do
    login admins(:super)

    assert_enqueued_emails 1 do
      with_fake_onboarding(fail_at: :submit_hia) do
        post bank_connections_path, params: { ebics_setup: valid_setup_params }
      end
    end

    assert_redirected_to organization_path(anchor: "bank_connection")
    assert_equal I18n.t("active_admin.resources.bank_connection.ebics_setup.flash.alert"), flash[:alert]
    assert_equal "errored", BankConnection.sole.state
    assert BankConnection.sole.status_details.dig("onboarding", "ini_submitted_at").present?
    assert_nil BankConnection.sole.status_details.dig("onboarding", "hia_submitted_at")
  end

  test "create initializes EBICS setup and submits INI and HIA" do
    login admins(:super)

    assert_enqueued_emails 2 do
      with_fake_onboarding do
        post bank_connections_path, params: {
          ebics_setup: valid_setup_params.transform_values { |value| value.is_a?(String) ? " #{value} " : value }
        }
      end
    end

    assert_redirected_to organization_path(anchor: "bank_connection")
    assert_equal I18n.t("active_admin.resources.bank_connection.ebics_setup.flash.notice"), flash[:notice]

    connection = BankConnection.sole
    assert_equal "ebics", connection.provider
    assert_equal "HOSTID", connection.name
    assert_not connection.active?
    assert_equal "waiting_for_bank", connection.state
    assert_equal "H005", connection.settings.fetch("protocol")
    assert_equal "CLIENTID", connection.credentials.fetch("client_id")
    assert_equal "PARTICIPANTID", connection.credentials.fetch("participant_id")
    assert_equal "BTD", connection.settings.dig("downloads", "payments", "btf", "order_type")
    assert_equal "CH", connection.settings.dig("downloads", "payments", "btf", "scope")
    assert_not connection.settings.key?("uploads")
    assert_equal 4096, connection.status_details.dig("onboarding", "target_bits")
    assert_equal admins(:super).id, connection.status_details.dig("onboarding", "initiated_by_admin_id")
    assert_equal admins(:super).email, connection.status_details.dig("onboarding", "initiated_by_admin_email")
    assert connection.status_details.dig("onboarding", "initiated_at").present?
    assert connection.status_details.dig("onboarding", "ini_submitted_at").present?
    assert connection.status_details.dig("onboarding", "hia_submitted_at").present?
  end

  private

  def login(admin)
    session = Session.create!(
      admin_email: admin.email,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
  end

  def valid_setup_params
    {
      url: "https://ebics.example.test",
      host_id: "HOSTID",
      client_id: "CLIENTID",
      participant_id: "PARTICIPANTID",
      confirmation: "1"
    }
  end

  def with_fake_onboarding(fail_at: nil, failure_class: nil, &block)
    factory = ->(connection: nil, **_options) {
      FakeOnboarding.new(connection: connection, fail_at: fail_at, failure_class: failure_class)
    }
    Billing::EBICS::Onboarding.stub(:new, factory, &block)
  end

  class FakeOnboarding
    attr_reader :connection

    def initialize(connection: nil, fail_at: nil, failure_class: nil)
      @tenant = Tenant.current
      @connection = connection
      @fail_at = fail_at
      @failure_class = failure_class
      @now = Time.zone.parse("2026-07-06 10:00")
    end

    def initialize_connection!(url:, host_id:, client_id:, participant_id:, name:, target_bits:)
      fail_preflight! if @fail_at == :initialize

      @connection = BankConnection.create!(
        provider: "ebics",
        name: name,
        active: false,
        state: "initializing",
        health_status: "unknown",
        credentials: {
          "url" => url,
          "host_id" => host_id,
          "participant_id" => participant_id,
          "client_id" => client_id
        },
        settings: { "protocol" => "H005" },
        status_details: {
          "onboarding" => {
            "state" => "initialized",
            "target_bits" => target_bits,
            "host_id" => host_id,
            "protocol" => "H005",
            "tenant" => @tenant
          }
        })
      { "initialized" => true }
    end

    def submit_ini!
      fail!("submit_ini") if @fail_at == :submit_ini

      update_onboarding!("ini_submitted", "ini_submitted_at")
      { "submitted" => true }
    end

    def submit_hia!
      fail!("submit_hia") if @fail_at == :submit_hia

      update_onboarding!("waiting_for_bank", "hia_submitted_at", connection_state: "waiting_for_bank")
      { "submitted" => true }
    end

    private

    def fail_preflight!
      error_class = @failure_class.is_a?(Class) ? @failure_class : @failure_class.constantize
      raise error_class, "EBICS version preflight failed"
    end

    def fail!(stage)
      update_onboarding!("errored", "#{stage}_failed_at", connection_state: "errored")
      connection.update_columns(
        last_error_class: failure_class_name,
        last_error_message: "EBICS onboarding failed during #{stage}")
      raise Billing::EBICS::UnsupportedOperation, "EBICS onboarding failed during #{stage}"
    end

    def failure_class_name
      @failure_class.is_a?(Class) ? @failure_class.name : @failure_class
    end

    def update_onboarding!(state, timestamp_key, connection_state: nil)
      details = connection.status_details.to_h.deep_stringify_keys
      onboarding = details.fetch("onboarding") { {} }
      details["onboarding"] = onboarding.merge(
        "state" => state,
        timestamp_key => @now.iso8601)
      attributes = { status_details: details }
      attributes[:state] = connection_state if connection_state
      connection.update!(attributes)
    end
  end
end
