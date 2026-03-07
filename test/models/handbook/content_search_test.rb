# frozen_string_literal: true

require "test_helper"

class HandbookContentSearchTest < ActiveSupport::TestCase
  setup do
    Handbook.clear_pages_cache!
    Handbook.clear_headings_cache!
  end

  # -- Content matching --

  test "content_search finds term in page body that is not in any heading" do
    # "camt.054" appears in the billing page body but not in any heading
    results = Handbook.content_search("camt.054", locale: :en)

    match = results.find { |r| r[:name] == "billing" }
    assert match, "Expected a content match for 'camt.054' in billing page"
    assert match[:snippet].present?, "Expected a snippet for the match"
  end

  test "content_search returns snippet containing surrounding context" do
    results = Handbook.content_search("camt.054", locale: :en)

    match = results.find { |r| r[:name] == "billing" }
    assert match, "Expected a match for 'camt.054'"
    # Snippet should be around SNIPPET_LENGTH chars
    assert match[:snippet].length <= 150, # allow for ellipsis
      "Snippet should be approximately #{Handbook::Search::SNIPPET_LENGTH} chars, got #{match[:snippet].length}"
    assert match[:snippet].length >= 20,
      "Snippet should have meaningful content, got #{match[:snippet].length} chars"
  end

  test "content_search returns title match when query matches page title" do
    results = Handbook.content_search("billing", locale: :en)

    match = results.find { |r| r[:name] == "billing" }
    assert match, "Expected a match for 'billing'"
    assert_nil match[:heading], "Title match should have nil heading"
    assert_nil match[:anchor], "Title match should have nil anchor"
  end

  test "content_search returns heading match with anchor" do
    results = Handbook.content_search("delivery cycles", locale: :en)

    match = results.find { |r| r[:anchor] == "delivery-cycles" }
    assert match, "Expected a heading match for 'delivery cycles'"
    assert_equal "Delivery cycles", match[:heading]
    assert_equal "Deliveries", match[:title]
  end

  # -- H3 heading matching --

  test "content_search finds H3 heading with anchor as heading match" do
    results = Handbook.content_search("setting up ebics", locale: :en)

    match = results.find { |r| r[:name] == "billing" && r[:anchor] == "ebics-setup" }
    assert match, "Expected a heading match for H3 'Setting up EBICS'"
    assert_equal "Setting up EBICS", match[:heading]
    assert_equal "Billing", match[:title]
  end

  test "content_search finds H3 heading match in French" do
    results = Handbook.content_search("mise en place ebics", locale: :fr)

    match = results.find { |r| r[:name] == "billing" && r[:anchor] == "ebics-setup" }
    assert match, "Expected a heading match for H3 'Mise en place d'EBICS' in French"
  end

  test "content_search finds H3 heading for manual import" do
    results = Handbook.content_search("manual import", locale: :en)

    match = results.find { |r| r[:name] == "billing" && r[:anchor] == "manual-import" }
    assert match, "Expected a heading match for H3 'Manual import'"
  end

  test "content_search finds H3 heading for trial baskets" do
    results = Handbook.content_search("trial baskets", locale: :en)

    match = results.find { |r| r[:name] == "billing" && r[:anchor] == "trial-baskets" }
    assert match, "Expected a heading match for H3 'Trial baskets'"
  end

  # -- Accent-insensitive matching --

  test "content_search is accent-insensitive" do
    results_accented = Handbook.content_search("éligibilité", locale: :fr)
    results_plain = Handbook.content_search("eligibilite", locale: :fr)

    assert_equal results_accented.map { |r| r[:name] },
      results_plain.map { |r| r[:name] },
      "Accented and plain queries should return same pages"
  end

  # -- Multi-term AND matching --

  test "content_search requires all terms to match (AND semantics)" do
    # Both "invoice" and "payment" appear in billing, but a very specific
    # combination like "invoice xyznonexistent" should find nothing
    results = Handbook.content_search("invoice xyznonexistent", locale: :en)
    assert_empty results, "Expected no results when one AND term doesn't match"
  end

  test "content_search matches when all terms appear in same section" do
    # "invoice" and "payment" both appear in billing page
    results = Handbook.content_search("invoice payment", locale: :en)

    match = results.find { |r| r[:name] == "billing" }
    assert match, "Expected billing page to match both 'invoice' and 'payment'"
  end

  # -- Ranking --

  test "title matches rank above heading matches" do
    results = Handbook.content_search("billing", locale: :en)

    title_match = results.find { |r| r[:name] == "billing" && r[:heading].nil? }
    heading_matches = results.select { |r| r[:heading].present? }

    if title_match && heading_matches.any?
      title_idx = results.index(title_match)
      heading_idx = results.index(heading_matches.first)
      assert title_idx < heading_idx,
        "Expected title match (index #{title_idx}) before heading match (index #{heading_idx})"
    end
  end

  test "title match ranks above body-only match" do
    results = Handbook.content_search("absence", locale: :en)

    title_match_idx = results.index { |r| r[:name] == "absence" && r[:heading].nil? }
    assert title_match_idx, "Expected a title match for 'absence'"

    # All results before the title match should also be title matches
    results[0...title_match_idx].each do |r|
      assert_nil r[:heading],
        "Expected only title matches before the 'absence' title match, got heading '#{r[:heading]}' for page '#{r[:name]}'"
    end
  end

  # -- Restricted/inactive exclusion --

  test "content_search excludes restricted pages" do
    original = Organization::RESTRICTED_FEATURES.dup
    Organization::RESTRICTED_FEATURES.replace([ :billing ])

    results = Handbook.content_search("invoice", locale: :en)
    assert_not results.any? { |r| r[:name] == "billing" },
      "Expected 'billing' page to be excluded when restricted"
  ensure
    Organization::RESTRICTED_FEATURES.replace(original)
  end

  test "content_search includes pages for inactive features" do
    assert_not Current.org.feature?(:bidding_round)

    results = Handbook.content_search("bidding", locale: :en)
    assert results.any? { |r| r[:name] == "bidding_round" },
      "Expected 'bidding_round' page to be included even when feature is inactive"
  end

  test "content_search excludes demo-only pages on non-demo tenants" do
    results = Handbook.content_search("setup", locale: :en)
    assert_not results.any? { |r| r[:name] == "setup" },
      "Expected 'setup' page to be excluded on non-demo tenant"
  end

  test "content_search includes demo-only pages on demo tenants" do
    with_demo_tenant do
      results = Handbook.content_search("setup", locale: :en)
      assert results.any? { |r| r[:name] == "setup" },
        "Expected 'setup' page to be included on demo tenant"
    end
  end

  test "content_search includes pages for active features" do
    assert Current.org.feature?(:absence)

    results = Handbook.content_search("absence", locale: :en)
    assert results.any? { |r| r[:name] == "absence" },
      "Expected 'absence' page to be included when feature is active"
  end

  # -- Short query handling --

  test "content_search returns empty for single character query" do
    assert_empty Handbook.content_search("a", locale: :en)
  end

  test "content_search returns empty for two character query" do
    assert_empty Handbook.content_search("ab", locale: :en)
  end

  test "content_search returns empty for blank query" do
    assert_empty Handbook.content_search("", locale: :en)
  end

  test "content_search returns empty for nil query" do
    assert_empty Handbook.content_search(nil, locale: :en)
  end

  test "content_search returns empty for whitespace-only query" do
    assert_empty Handbook.content_search("   ", locale: :en)
  end

  # -- No results --

  test "content_search returns empty for unmatched query" do
    assert_empty Handbook.content_search("xyznonexistent", locale: :en)
  end

  # -- Capping --

  test "content_search returns at most MAX_CONTENT_RESULTS results" do
    # Use a very common word that appears in many pages
    results = Handbook.content_search("the", locale: :en)
    assert results.size <= Handbook::Search::MAX_CONTENT_RESULTS,
      "Expected at most #{Handbook::Search::MAX_CONTENT_RESULTS} results, got #{results.size}"
  end

  # -- Multiple heading matches per page --

  test "content_search returns multiple heading matches from same page" do
    results = Handbook.content_search("importation", locale: :fr)

    billing_results = results.select { |r| r[:name] == "billing" }
    assert billing_results.size >= 2,
      "Expected at least 2 heading matches for 'importation' in billing page, got #{billing_results.size}"

    anchors = billing_results.map { |r| r[:anchor] }
    assert_includes anchors, "automatic_payments_processing"
    assert_includes anchors, "manual-import"
  end

  test "content_search returns one result per page for title match" do
    results = Handbook.content_search("billing", locale: :en)

    billing_results = results.select { |r| r[:name] == "billing" }
    assert_equal 1, billing_results.size,
      "Expected exactly one result for title match, got #{billing_results.size}"
    assert_nil billing_results.first[:heading], "Title match should have nil heading"
  end

  test "content_search returns one result per page for body-only match" do
    results = Handbook.content_search("camt.054", locale: :en)

    billing_results = results.select { |r| r[:name] == "billing" }
    assert_equal 1, billing_results.size,
      "Expected exactly one body-only result per page, got #{billing_results.size}"
  end

  # -- ERB stripping --

  test "pages_for strips ERB tags from searchable text" do
    pages = Handbook.pages_for(:en)

    pages.each do |page|
      page[:sections].each do |section|
        assert_not_includes section[:raw_text], "<%",
          "Expected no ERB open tags in raw_text for page '#{page[:name]}'"
        assert_not_includes section[:raw_text], "%>",
          "Expected no ERB close tags in raw_text for page '#{page[:name]}'"
      end
    end
  end

  # -- Markdown cleanup --

  test "pages_for strips markdown links from searchable text" do
    pages = Handbook.pages_for(:en)

    # Check that [text](url) patterns are cleaned
    pages.each do |page|
      page[:sections].each do |section|
        # Should not contain markdown link syntax — only the text should remain
        refute_match(/\[([^\]]+)\]\([^)]+\)/, section[:raw_text],
          "Expected markdown links to be stripped in page '#{page[:name]}'")
      end
    end
  end

  # -- Caching --

  test "pages_for caches results per locale" do
    first = Handbook.pages_for(:en)
    second = Handbook.pages_for(:en)

    assert_same first, second,
      "Expected pages_for to return the same cached object"
  end

  test "pages_for caches separately per locale" do
    en_pages = Handbook.pages_for(:en)
    fr_pages = Handbook.pages_for(:fr)

    refute_same en_pages, fr_pages,
      "Expected different objects for different locales"
  end

  test "clear_pages_cache! resets the cache" do
    Handbook.pages_for(:en)
    Handbook.clear_pages_cache!

    fresh = Handbook.pages_for(:en)
    assert_kind_of Array, fresh
    assert fresh.any?, "Expected pages to be re-parsed after cache clear"
  end

  # -- Result structure --

  test "content_search results have required keys" do
    results = Handbook.content_search("billing", locale: :en)
    assert results.any?, "Expected at least one result"

    results.each do |result|
      assert result.key?(:name), "Missing :name key"
      assert result.key?(:title), "Missing :title key"
      assert result.key?(:heading), "Missing :heading key"
      assert result.key?(:anchor), "Missing :anchor key"
      assert result.key?(:snippet), "Missing :snippet key"
      assert_not result.key?(:rank), "Internal :rank key should be stripped"
    end
  end

  # -- Locale-specific matching --

  test "content_search matches locale-specific content" do
    results = Handbook.content_search("facturation", locale: :fr)

    match = results.find { |r| r[:name] == "billing" }
    assert match, "Expected to find billing page by French title 'Facturation'"
  end

  test "content_search does not match English content in French locale" do
    # "EBICS" appears in both locales, but "overdue notice" is English-only heading text
    results = Handbook.content_search("overdue notice", locale: :fr)

    en_match = results.find { |r| r[:name] == "billing" && r[:heading] == "Overdue notice" }
    assert_nil en_match,
      "Expected no English heading match in French locale"
  end

  # -- Section splitting --

  test "pages_for splits content into sections by h2 headings" do
    pages = Handbook.pages_for(:en)

    billing = pages.find { |p| p[:name] == "billing" }
    assert billing, "Expected to find billing page"

    # Billing has multiple ## headings, so it should have multiple sections
    assert billing[:sections].size > 1,
      "Expected multiple sections in billing page, got #{billing[:sections].size}"

    # First section should have nil heading (intro before first ##)
    intro = billing[:sections].first
    assert_nil intro[:heading], "First section should have nil heading (intro)"

    # Subsequent sections should have headings
    subsequent = billing[:sections][1..]
    assert subsequent.all? { |s| s[:heading].present? },
      "Expected all subsequent sections to have headings"
  end

  # -- Country-specific sections --

  test "content_search finds QR-IBAN content for CH org" do
    assert_equal "CH", Current.org.country_code

    results = Handbook.content_search("QR-IBAN", locale: :en)

    match = results.find { |r| r[:name] == "billing" }
    assert match, "Expected a content match for 'QR-IBAN' in billing page for CH org"
  end

  test "content_search excludes QR-IBAN content for non-CH org" do
    Current.org.update_column(:country_code, "DE")
    Handbook.clear_pages_cache!

    results = Handbook.content_search("QR-IBAN", locale: :en)

    match = results.find { |r| r[:name] == "billing" }
    assert_nil match, "Expected no 'QR-IBAN' content match for DE org"
  ensure
    Current.org.update_column(:country_code, "CH")
  end

  test "content_search finds Alternative Bank content for CH org" do
    assert_equal "CH", Current.org.country_code

    results = Handbook.content_search("Alternative Bank", locale: :en)

    match = results.find { |r| r[:name] == "billing" }
    assert match, "Expected a content match for 'Alternative Bank' in billing page for CH org"
  end

  test "content_search excludes Alternative Bank content for non-CH org" do
    Current.org.update_column(:country_code, "FR")
    Handbook.clear_pages_cache!

    results = Handbook.content_search("Alternative Bank", locale: :en)

    match = results.find { |r| r[:name] == "billing" }
    assert_nil match, "Expected no 'Alternative Bank' content match for FR org"
  ensure
    Current.org.update_column(:country_code, "CH")
  end

  test "content_search still finds shared content regardless of country" do
    results = Handbook.content_search("overdue notice", locale: :en)
    match = results.find { |r| r[:name] == "billing" }
    assert match, "Expected 'overdue notice' match for CH org"

    Current.org.update_column(:country_code, "DE")
    Handbook.clear_pages_cache!

    results = Handbook.content_search("overdue notice", locale: :en)
    match = results.find { |r| r[:name] == "billing" }
    assert match, "Expected 'overdue notice' match for DE org too"
  ensure
    Current.org.update_column(:country_code, "CH")
  end

  test "pages_for caches separately per country code" do
    Handbook.pages_for(:en)

    Current.org.update_column(:country_code, "DE")
    Handbook.pages_for(:en)

    en_ch = Handbook.instance_variable_get(:@pages)[:"en_CH"]
    en_de = Handbook.instance_variable_get(:@pages)[:"en_DE"]

    assert en_ch, "Expected cached pages for en_CH"
    assert en_de, "Expected cached pages for en_DE"
    refute_same en_ch, en_de, "Expected different objects for different country codes"
  ensure
    Current.org.update_column(:country_code, "CH")
  end

  test "pages_for strips country markers from searchable text" do
    pages = Handbook.pages_for(:en)

    pages.each do |page|
      page[:sections].each do |section|
        assert_not_includes section[:raw_text], "<!-- country:",
          "Expected no country markers in raw_text for page '#{page[:name]}'"
        assert_not_includes section[:raw_text], "<!-- /country:",
          "Expected no country closing markers in raw_text for page '#{page[:name]}'"
      end
    end
  end
end
