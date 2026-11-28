# frozen_string_literal: true

require "test_helper"
require "openssl"
require "tempfile"

class PDF::EBICSInitializationLetterTest < ActiveSupport::TestCase
  setup do
    BankConnection.delete_all
    org(country_code: "CH")
  end

  test "renders initialization letter without private key material" do
    connection = initialized_connection
    letter = PDF::EBICSInitializationLetter.new(
      connection,
      generated_at: Time.utc(2026, 7, 5, 10, 0, 0))

    pdf_bytes = I18n.with_locale(:en) { letter.render }
    strings = PDF::Inspector::Text.analyze(pdf_bytes).strings
    pages = PDF::Inspector::Page.analyze(pdf_bytes).pages
    text = strings.join("\n")

    assert_equal "application/pdf", letter.content_type
    assert_equal "ebics_initialization_letter_hostid_2026-07-05.pdf", letter.filename
    assert_equal 3, pages.size
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

  test "renders localized HTML and writes PDF to file across all locales" do
    connection = initialized_connection
    letter = PDF::EBICSInitializationLetter.new(
      connection,
      generated_at: Time.utc(2026, 7, 5, 10, 0, 0))

    {
      fr: "Page 1 / 3",
      de: "Seite 2 / 3",
      it: "Pagina 3 / 3",
      nl: "Pagina 1 / 3"
    }.each do |locale, expected_footer|
      html = I18n.with_locale(locale) { letter.render_html }
      assert_includes html, %(lang="#{locale}")
      assert_includes html, expected_footer
    end

    Tempfile.create([ "ebics", ".pdf" ]) do |file|
      I18n.with_locale(:en) { letter.render_file(file.path) }
      bytes = File.binread(file.path)
      assert bytes.start_with?("%PDF-")
      assert_equal 3, PDF::Inspector::Page.analyze(bytes).pages.size
    end
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
