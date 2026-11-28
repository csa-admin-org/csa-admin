# frozen_string_literal: true

require "test_helper"
require "tempfile"

class PDF::SEPAMandateTest < ActiveSupport::TestCase
  setup do
    german_org(
      name: "Demo Bauernhof",
      creditor_name: "Demo Bauernhof",
      creditor_street: "Hofstrasse 42",
      creditor_zip: "30159",
      creditor_city: "Hannover",
      sepa_creditor_identifier: "DE98ZZZ09999999999")
  end

  test "renders SEPA mandate PDF with creditor, debtor, IBAN, and legal text" do
    member = members(:anna)
    member.update!(
      name: "Anna Muster",
      language: "de",
      country_code: "DE",
      street: "Hauptstraße 1",
      zip: "10115",
      city: "Berlin")
    mandate = SEPAMandate.create!(
      member: member,
      iban: "DE21500500009876543210",
      umr: "UMR-42",
      signed_on: Date.new(2026, 8, 11),
      source: "admin")

    pdf = PDF::SEPAMandate.new(mandate)
    pdf_bytes = I18n.with_locale(:de) { pdf.render }
    strings = PDF::Inspector::Text.analyze(pdf_bytes).strings
    pages = PDF::Inspector::Page.analyze(pdf_bytes).pages
    text = strings.join("\n")

    assert_equal "application/pdf", pdf.content_type
    assert_equal "sepa_mandate_UMR-42_2026-08-11.pdf", pdf.filename
    assert_equal mandate, pdf.mandate
    assert_equal member, pdf.member
    assert_equal 1, pages.size
    assert_includes text, "SEPA-Lastschriftmandat"
    assert_includes text, "Demo Bauernhof"
    assert_includes text, "Hofstrasse 42"
    assert_includes text, "30159 Hannover"
    assert_includes text, "DE98ZZZ09999999999"
    assert_includes text, "Anna Muster"
    assert_includes text, "Hauptstraße 1"
    assert_includes text, "10115 Berlin"
    assert_includes text, "DE21 5005 0000 9876 5432 10"
    assert_includes text, "UMR-42"
    assert_includes text, "11. August 2026"
    assert_includes text, "Ich ermächtige Demo Bauernhof"
    assert_includes text, "Hinweis: Ich kann innerhalb von acht Wochen"
    assert_includes text, "Detaillierte Einwilligungsnachweise"
    assert_not_includes text, "127.0.0.1"
  end

  test "renders localized HTML across all locales and writes PDF to file" do
    member = members(:anna)
    member.update!(language: "de", country_code: "DE")
    mandate = SEPAMandate.create!(
      member: member,
      iban: "DE21500500009876543210",
      umr: "UMR-99",
      signed_on: Date.new(2026, 8, 11),
      source: "admin")

    pdf = PDF::SEPAMandate.new(mandate)

    {
      en: "SEPA Direct Debit Mandate",
      fr: "Mandat de prélèvement SEPA",
      de: "SEPA-Lastschriftmandat",
      it: "Mandato di addebito diretto SEPA",
      nl: "SEPA-machtiging doorlopende incasso"
    }.each do |locale, expected_title|
      html = I18n.with_locale(locale) { pdf.render_html }
      assert_includes html, %(lang="#{locale}")
      assert_includes html, expected_title
    end

    Tempfile.create([ "sepa_mandate", ".pdf" ]) do |file|
      I18n.with_locale(:de) { pdf.render_file(file.path) }
      bytes = File.binread(file.path)
      assert bytes.start_with?("%PDF-")
      assert_equal 1, PDF::Inspector::Page.analyze(bytes).pages.size
    end
  end
end
