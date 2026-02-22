# frozen_string_literal: true

require "test_helper"

class HandbookContentSearchTest < ActiveSupport::TestCase
  setup do
    Handbook.clear_pages_cache!
    Handbook.clear_headings_cache!
  end

  # -- Content matching --

  test "content_search finds term in page body that is not in any heading" do
    # "EBICS" appears in the billing page body (payments section) but not in any h1/h2
    results = Handbook.content_search("ebics", locale: :en)

    match = results.find { |r| r[:name] == "billing" }
    assert match, "Expected a content match for 'ebics' in billing page"
    assert match[:snippet].present?, "Expected a snippet for the match"
  end

  test "content_search returns snippet containing surrounding context" do
    results = Handbook.content_search("ebics", locale: :en)

    match = results.find { |r| r[:name] == "billing" }
    assert match, "Expected a match for 'ebics'"
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

  # -- One result per page --

  test "content_search returns at most one result per page" do
    results = Handbook.content_search("billing", locale: :en)

    page_names = results.map { |r| r[:name] }
    assert_equal page_names.uniq.size, page_names.size,
      "Expected at most one result per page, got duplicates: #{page_names.tally.select { |_, v| v > 1 }}"
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
end
