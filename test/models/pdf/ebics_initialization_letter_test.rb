# frozen_string_literal: true

require "test_helper"
require "openssl"

class PDF::EBICSInitializationLetterTest < ActiveSupport::TestCase
  setup do
    BankConnection.delete_all
    org(country_code: "CH")
  end

  test "renders initialization letter without private key material" do
    connection = initialized_connection

    strings = I18n.with_locale(:en) do
      PDF::Inspector::Text.analyze(PDF::EBICSInitializationLetter.new(
        connection,
        generated_at: Time.utc(2026, 7, 5, 10, 0, 0)).render).strings
    end
    text = strings.join("\n")

    assert_includes text, "Initialization letter for SIGNATURE certificate (A006)"
    assert_includes text, "Initialization letter for AUTHENTICATION certificate (X002)"
    assert_includes text, "Initialization letter for ENCRYPTION certificate (E002)"
    assert_includes text, "Host-ID"
    assert_includes text, "HOSTID"
    assert_includes text, "User-ID"
    assert_includes text, "PARTICIPANTID"
    assert_includes text, "Partner-ID"
    assert_includes text, "CLIENTID"
    assert_includes text, "Hash"
    assert_includes text, "Page 1 / 3"
    assert_includes text, "Page 2 / 3"
    assert_includes text, "Page 3 / 3"
    assert_not_includes text, "PRIVATE KEY"
    assert_not_includes text, connection.credentials.fetch("secret")
    assert_not_includes text, connection.credentials.fetch("keys").first(80)
  end

  private

  def initialized_connection
    Billing::EBICS::Onboarding.new(
      now: Time.zone.parse("2026-07-05 10:00"),
      key_generator: ->(_bits) { OpenSSL::PKey::RSA.generate(2048) },
      version_probe_factory: -> { SuccessfulVersionProbe.new }).initialize_connection!(
        url: "https://ebics.example.test",
        host_id: "HOSTID",
        client_id: "CLIENTID",
        participant_id: "PARTICIPANTID",
        name: "Test Bank",
        target_bits: 2048)
    BankConnection.last
  end

  class SuccessfulVersionProbe
    def check!(url:, host_id:) = true
  end
end
