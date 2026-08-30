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

  test "filter_country_sections negation keeps content for non-matching country" do
    text = <<~MD
      Intro.

      <!-- country:!CH -->
      Non-Swiss content.
      <!-- /country:!CH -->

      Outro.
    MD

    de_result = Handbook.filter_country_sections(text, "DE")
    assert_includes de_result, "Non-Swiss content."
    assert_includes de_result, "Intro."
    assert_includes de_result, "Outro."

    ch_result = Handbook.filter_country_sections(text, "CH")
    assert_not_includes ch_result, "Non-Swiss content."
    assert_includes ch_result, "Intro."
    assert_includes ch_result, "Outro."
  end

  test "filter_country_sections negation combined with positive block" do
    text = <<~MD
      <!-- country:CH -->
      Swiss only.
      <!-- /country:CH -->

      <!-- country:!CH -->
      Everyone except Swiss.
      <!-- /country:!CH -->
    MD

    ch_result = Handbook.filter_country_sections(text, "CH")
    assert_includes ch_result, "Swiss only."
    assert_not_includes ch_result, "Everyone except Swiss."

    de_result = Handbook.filter_country_sections(text, "DE")
    assert_not_includes de_result, "Swiss only."
    assert_includes de_result, "Everyone except Swiss."

    nl_result = Handbook.filter_country_sections(text, "NL")
    assert_not_includes nl_result, "Swiss only."
    assert_includes nl_result, "Everyone except Swiss."
  end

  test "title reads the markdown H1" do
    handbook = Handbook.new("announcements", binding)

    assert_equal "Announcements", handbook.title
  end

  test "body omits the page H1" do
    handbook = Handbook.new("announcements", binding)

    assert_not_includes handbook.body, "<h1"
    assert_includes handbook.body, "Announcements are short messages"
    assert_includes handbook.body, "How It Works"
  end

  test "demo_only? returns true for setup page" do
    handbook = Handbook.new("setup", binding)
    assert handbook.demo_only?
  end

  test "demo_only? returns false for non-setup pages" do
    handbook = Handbook.new("getting_started", binding)
    assert_not handbook.demo_only?
  end

  test "getting_started sorts before other pages" do
    start = Handbook.new("getting_started", binding)
    other = Handbook.new("announcements", binding)

    assert_operator start.send(:pinned_rank), :<, other.send(:pinned_rank)
  end

  test "subtitles are chapter headings with anchors" do
    billing = Handbook.new("billing", binding)
    ids = billing.subtitles.map(&:last)

    assert_includes ids, "memberships"
    assert_includes ids, "invoice-types"
    assert_not_includes ids, "billing-cookbook"
    assert_not_includes ids, "trial-baskets"
  end

  test "billing body omits inactive feature sections" do
    assert_not Current.org.feature?(:shares)
    assert_not Current.org.feature?(:vat)

    body = Handbook.new("billing", binding).body
    doc = Nokogiri::HTML::DocumentFragment.parse(body)
    types = doc.at_css("#invoice-types")&.parent&.at_css("table")

    assert types, "Expected one invoice-types table"
    headers = types.css("tr").map { |tr| tr.at_css("td,th")&.text.to_s }
    assert_includes headers, "Membership"
    assert_includes headers, "Annual fee"
    assert_includes headers, "Shop order"
    assert_includes headers, "Other"
    assert_not headers.include?("Share capital")
    assert_not_includes body, "id=\"share-capital\""
    assert_not_includes body, "id=\"vat\""
    assert_includes body, "id=\"memberships\""
  end

  def current_admin
    admins(:super)
  end
end
