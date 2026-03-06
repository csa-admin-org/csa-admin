# frozen_string_literal: true

require "test_helper"

class HandbookTest < ActiveSupport::TestCase
  test "filter_country_sections keeps matching country block content" do
    text = <<~MD
      Some intro text.

      <!-- country:CH -->
      Swiss-specific content about QR-IBAN.
      <!-- /country:CH -->

      Some outro text.
    MD

    result = Handbook.filter_country_sections(text, "CH")

    assert_includes result, "Swiss-specific content about QR-IBAN."
    assert_includes result, "Some intro text."
    assert_includes result, "Some outro text."
    assert_not_includes result, "<!-- country:CH -->"
    assert_not_includes result, "<!-- /country:CH -->"
  end

  test "filter_country_sections removes non-matching country block entirely" do
    text = <<~MD
      Some intro text.

      <!-- country:CH -->
      Swiss-specific content about QR-IBAN.
      <!-- /country:CH -->

      Some outro text.
    MD

    result = Handbook.filter_country_sections(text, "DE")

    assert_not_includes result, "Swiss-specific content about QR-IBAN."
    assert_includes result, "Some intro text."
    assert_includes result, "Some outro text."
  end

  test "filter_country_sections handles multiple country blocks" do
    text = <<~MD
      Intro.

      <!-- country:CH -->
      Swiss content.
      <!-- /country:CH -->

      Middle.

      <!-- country:DE -->
      German content.
      <!-- /country:DE -->

      Outro.
    MD

    result = Handbook.filter_country_sections(text, "CH")

    assert_includes result, "Swiss content."
    assert_not_includes result, "German content."
    assert_includes result, "Intro."
    assert_includes result, "Middle."
    assert_includes result, "Outro."
  end

  test "filter_country_sections handles block with H2 heading" do
    text = <<~MD
      # Billing

      <!-- country:CH -->
      ## QR-Invoices (Switzerland) {#qr-invoices}

      CSA Admin generates QR-invoices.
      <!-- /country:CH -->

      ## Memberships {#memberships}

      Membership billing is automated.
    MD

    ch_result = Handbook.filter_country_sections(text, "CH")
    assert_includes ch_result, "## QR-Invoices (Switzerland) {#qr-invoices}"
    assert_includes ch_result, "CSA Admin generates QR-invoices."
    assert_includes ch_result, "## Memberships {#memberships}"

    de_result = Handbook.filter_country_sections(text, "DE")
    assert_not_includes de_result, "QR-Invoices"
    assert_not_includes de_result, "QR-invoices"
    assert_includes de_result, "## Memberships {#memberships}"
  end

  test "filter_country_sections leaves text without markers unchanged" do
    text = "No country-specific content here.\n"

    assert_equal text, Handbook.filter_country_sections(text, "CH")
    assert_equal text, Handbook.filter_country_sections(text, "DE")
  end

  test "filter_country_sections handles adjacent country blocks" do
    text = <<~MD
      <!-- country:CH -->
      Swiss.
      <!-- /country:CH -->
      <!-- country:FR -->
      French.
      <!-- /country:FR -->
    MD

    ch_result = Handbook.filter_country_sections(text, "CH")
    assert_includes ch_result, "Swiss."
    assert_not_includes ch_result, "French."

    fr_result = Handbook.filter_country_sections(text, "FR")
    assert_not_includes fr_result, "Swiss."
    assert_includes fr_result, "French."
  end

  test "filter_country_sections does not cross-match mismatched closing tags" do
    text = <<~MD
      <!-- country:CH -->
      Swiss content.
      <!-- /country:CH -->

      Shared content.

      <!-- country:DE -->
      German content.
      <!-- /country:DE -->
    MD

    result = Handbook.filter_country_sections(text, "FR")

    assert_not_includes result, "Swiss content."
    assert_not_includes result, "German content."
    assert_includes result, "Shared content."
  end

  test "filter_country_sections defaults to Current.org.country_code" do
    assert_equal "CH", Current.org.country_code

    text = <<~MD
      <!-- country:CH -->
      Swiss.
      <!-- /country:CH -->
    MD

    result = Handbook.filter_country_sections(text)
    assert_includes result, "Swiss."
  end

  test "filter_country_sections handles inline content between markers" do
    text = "Before. <!-- country:CH -->Swiss.<!-- /country:CH --> After."

    ch_result = Handbook.filter_country_sections(text, "CH")
    assert_includes ch_result, "Swiss."
    assert_includes ch_result, "Before."
    assert_includes ch_result, "After."

    de_result = Handbook.filter_country_sections(text, "DE")
    assert_not_includes de_result, "Swiss."
    assert_includes de_result, "Before."
    assert_includes de_result, "After."
  end
end
