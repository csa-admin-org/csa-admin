# frozen_string_literal: true

require "test_helper"

class BankConnection::EBICSSetupTest < ActiveSupport::TestCase
  test "normalizes input and builds onboarding attributes" do
    setup = BankConnection::EBICSSetup.new(
      url: " https://ebics.example.test ",
      host_id: " HOSTID ",
      client_id: " CLIENTID ",
      participant_id: " PARTICIPANTID ",
      confirmation: "1")

    assert_predicate setup, :valid?
    assert_equal({
      url: "https://ebics.example.test",
      host_id: "HOSTID",
      client_id: "CLIENTID",
      participant_id: "PARTICIPANTID",
      name: "HOSTID",
      target_bits: 4096
    }, setup.onboarding_attributes)
  end

  test "validates required contract identifiers" do
    setup = BankConnection::EBICSSetup.new(confirmation: true)

    assert_not_predicate setup, :valid?
    assert_not_empty setup.errors[:url]
    assert_not_empty setup.errors[:host_id]
    assert_not_empty setup.errors[:client_id]
    assert_not_empty setup.errors[:participant_id]
  end

  test "validates URL format" do
    assert_invalid_url "ebics.example.test"
    assert_invalid_url "http://ebics.example.test"
    assert_invalid_url "https://user:secret@ebics.example.test"
    assert_invalid_url "https://"
    assert_invalid_url "https://ebics.example.test/with space"
  end

  test "uses Swiss payment download preset without upload settings" do
    org(country_code: "CH", sepa_creditor_identifier: nil)

    settings = ebics_setup.settings_for(Current.org)

    assert_equal "H005", settings.fetch("protocol")
    assert_equal "btf", settings.dig("downloads", "payments", "mode")
    assert_equal "BTD", settings.dig("downloads", "payments", "btf", "order_type")
    assert_equal "REP", settings.dig("downloads", "payments", "btf", "service_name")
    assert_equal "CH", settings.dig("downloads", "payments", "btf", "scope")
    assert_equal "camt.054", settings.dig("downloads", "payments", "btf", "message_name")
    assert_equal "04", settings.dig("downloads", "payments", "btf", "version")
    assert_not settings.key?("uploads")
  end

  test "uses German payment and direct debit presets when SEPA is configured" do
    german_org(sepa_creditor_identifier: "DE98ZZZ09999999999")

    settings = ebics_setup.settings_for(Current.org)

    assert_equal "EOP", settings.dig("downloads", "payments", "btf", "service_name")
    assert_equal "DE", settings.dig("downloads", "payments", "btf", "scope")
    assert_equal "camt.053", settings.dig("downloads", "payments", "btf", "message_name")
    assert_equal "btf", settings.dig("uploads", "sepa_direct_debit", "mode")
    assert_equal "pain.008.001.08", settings.dig("uploads", "sepa_direct_debit", "schema")
    assert_equal "BTU", settings.dig("uploads", "sepa_direct_debit", "btf", "order_type")
    assert_equal "SDD", settings.dig("uploads", "sepa_direct_debit", "btf", "service_name")
    assert_equal "DE", settings.dig("uploads", "sepa_direct_debit", "btf", "scope")
    assert_equal "XML", settings.dig("uploads", "sepa_direct_debit", "btf", "container")
    assert_equal "pain.008", settings.dig("uploads", "sepa_direct_debit", "btf", "message_name")
  end

  test "adds live endpoint check errors" do
    setup = ebics_setup

    setup.add_endpoint_check_error

    assert_includes setup.errors[:url], I18n.t("active_admin.resources.bank_connection.ebics_setup.validation.endpoint")
    assert_includes setup.errors[:base], I18n.t("active_admin.resources.bank_connection.ebics_setup.validation.retry_or_contact")
  end

  test "adds live host ID check errors" do
    setup = ebics_setup

    setup.add_host_id_check_error

    assert_includes setup.errors[:host_id], I18n.t("active_admin.resources.bank_connection.ebics_setup.validation.host_id")
    assert_includes setup.errors[:base], I18n.t("active_admin.resources.bank_connection.ebics_setup.validation.retry_or_contact")
  end

  test "adds live identifier check errors" do
    setup = ebics_setup

    setup.add_identifier_check_error

    assert_empty setup.errors[:host_id]
    assert_includes setup.errors[:client_id], I18n.t("active_admin.resources.bank_connection.ebics_setup.validation.identifiers")
    assert_includes setup.errors[:participant_id], I18n.t("active_admin.resources.bank_connection.ebics_setup.validation.identifiers")
    assert_includes setup.errors[:base], I18n.t("active_admin.resources.bank_connection.ebics_setup.validation.retry_or_contact")
  end

  test "limits self-service setup to supported countries" do
    org(country_code: "CH")
    assert BankConnection::EBICSSetup.supported_country?(Current.org)

    german_org
    assert BankConnection::EBICSSetup.supported_country?(Current.org)

    france_org
    assert_not BankConnection::EBICSSetup.supported_country?(Current.org)
  end

  private

  def assert_invalid_url(url)
    setup = ebics_setup.tap { |setup| setup.url = url }

    assert_not_predicate setup, :valid?
    assert_not_empty setup.errors[:url]
  end

  def ebics_setup
    BankConnection::EBICSSetup.new(
      url: "https://ebics.example.test",
      host_id: "HOSTID",
      client_id: "CLIENTID",
      participant_id: "PARTICIPANTID",
      confirmation: true)
  end
end
