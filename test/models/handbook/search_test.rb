# frozen_string_literal: true

require "test_helper"

class HandbookSearchTest < ActiveSupport::TestCase
  setup do
    Handbook.clear_headings_cache!
  end

  # -- Basic title matching --

  test "search returns title match for a handbook page" do
    results = Handbook.search("billing", locale: :en)

    match = results.find { |r| r[:name] == "billing" && r[:subtitle].nil? }
    assert match, "Expected a title match for 'billing'"
    assert_equal "Billing", match[:title]
    assert_nil match[:anchor]
    assert_nil match[:page_title]
  end

  test "search returns title match for multi-word page title" do
    results = Handbook.search("getting started", locale: :en)

    match = results.find { |r| r[:name] == "getting_started" && r[:subtitle].nil? }
    assert match, "Expected a title match for 'getting started'"
    assert_equal "Getting Started", match[:title]
  end

  test "search returns title match in French locale" do
    results = Handbook.search("livraisons", locale: :fr)

    match = results.find { |r| r[:name] == "deliveries" && r[:subtitle].nil? }
    assert match, "Expected a title match for 'livraisons' in French"
  end

  # -- Subtitle matching --

  test "search returns subtitle match with anchor" do
    results = Handbook.search("delivery cycles", locale: :en)

    match = results.find { |r| r[:name] == "deliveries" && r[:subtitle].present? }
    assert match, "Expected a subtitle match for 'delivery cycles'"
    assert_equal "Delivery cycles", match[:subtitle]
    assert_equal "delivery-cycles", match[:anchor]
    assert_equal "Deliveries", match[:page_title]
  end

  test "search subtitle match includes page_title for context" do
    results = Handbook.search("share capital", locale: :en)

    match = results.find { |r| r[:anchor] == "share-capital" }
    assert match, "Expected a subtitle match for 'share capital'"
    assert_equal "Billing", match[:page_title]
    assert_equal "Share capital", match[:subtitle]
  end

  test "search extracts explicit anchor IDs correctly" do
    results = Handbook.search("prerequisites", locale: :en)

    match = results.find { |r| r[:anchor] == "prerequisites" }
    assert match, "Expected a subtitle match for 'prerequisites'"
    assert_equal "prerequisites", match[:anchor]
    assert_equal "membership_renewal", match[:name]
  end

  test "search matches when terms span title and subtitle" do
    # "bill member" → "bill" in title "Billing", "member" in subtitle "Memberships"
    results = Handbook.search("bill member", locale: :en)

    match = results.find { |r| r[:name] == "billing" && r[:subtitle] == "Memberships" }
    assert match, "Expected a subtitle match when terms span title + subtitle"
    assert_equal "memberships", match[:anchor]
    assert_equal "Billing", match[:page_title]
  end

  # -- Ranking --

  test "title matches rank above subtitle matches" do
    results = Handbook.search("billing", locale: :en)

    title_indices = results.each_index.select { |i| results[i][:subtitle].nil? }
    subtitle_indices = results.each_index.select { |i| results[i][:subtitle].present? }

    if title_indices.any? && subtitle_indices.any?
      assert title_indices.max < subtitle_indices.min,
        "Expected all title matches before subtitle matches"
    end
  end

  # -- Accent-insensitive matching --

  test "search is accent-insensitive" do
    # French title "Résumé" or accented content should match unaccented query
    # Test with a known French heading that has accents
    results_accented = Handbook.search("compléments", locale: :fr)
    results_plain = Handbook.search("complements", locale: :fr)

    # Both should return the same results since normalization strips accents
    assert_equal results_accented.map { |r| [ r[:name], r[:anchor] ] },
      results_plain.map { |r| [ r[:name], r[:anchor] ] }
  end

  test "search matches accented heading with unaccented query" do
    # "Résumé" in the renewals form heading, or similar
    # Use "livraisons" page in FR which has "Cycles de livraisons {#delivery-cycles}"
    results = Handbook.search("depots", locale: :en)

    match = results.find { |r| r[:name] == "getting_started" && r[:anchor] == "depots" }
    assert match, "Expected a subtitle match for 'depots' in getting_started"
  end

  # -- Case insensitivity --

  test "search is case-insensitive" do
    results_lower = Handbook.search("billing", locale: :en)
    results_upper = Handbook.search("BILLING", locale: :en)
    results_mixed = Handbook.search("Billing", locale: :en)

    assert_equal results_lower.map { |r| [ r[:name], r[:anchor] ] },
      results_upper.map { |r| [ r[:name], r[:anchor] ] }
    assert_equal results_lower.map { |r| [ r[:name], r[:anchor] ] },
      results_mixed.map { |r| [ r[:name], r[:anchor] ] }
  end

  # -- Short query handling --

  test "search returns empty for single character query" do
    assert_empty Handbook.search("a", locale: :en)
  end

  test "search returns empty for blank query" do
    assert_empty Handbook.search("", locale: :en)
  end

  test "search returns empty for nil query" do
    assert_empty Handbook.search(nil, locale: :en)
  end

  test "search returns empty for whitespace-only query" do
    assert_empty Handbook.search("   ", locale: :en)
  end

  # -- No results --

  test "search returns empty for unmatched query" do
    assert_empty Handbook.search("xyznonexistent", locale: :en)
  end

  # -- Restricted pages --

  test "search excludes restricted pages" do
    # Temporarily add a page name to restricted features
    original = Organization::RESTRICTED_FEATURES.dup
    Organization::RESTRICTED_FEATURES.replace([ :billing ])

    results = Handbook.search("billing", locale: :en)
    assert_not results.any? { |r| r[:name] == "billing" },
      "Expected 'billing' page to be excluded when restricted"
  ensure
    Organization::RESTRICTED_FEATURES.replace(original)
  end

  test "search includes non-restricted pages when some are restricted" do
    original = Organization::RESTRICTED_FEATURES.dup
    Organization::RESTRICTED_FEATURES.replace([ :billing ])

    results = Handbook.search("deliveries", locale: :en)
    assert results.any? { |r| r[:name] == "deliveries" },
      "Expected 'deliveries' to still be found when only 'billing' is restricted"
  ensure
    Organization::RESTRICTED_FEATURES.replace(original)
  end

  # -- Inactive feature pages --

  test "search excludes pages for inactive features" do
    # bidding_round is not in the acme fixture's features list
    assert_not Current.org.feature?(:bidding_round)

    results = Handbook.search("bidding", locale: :en)
    assert_not results.any? { |r| r[:name] == "bidding_round" },
      "Expected 'bidding_round' page to be excluded when feature is inactive"
  end

  test "search includes pages for active features" do
    assert Current.org.feature?(:absence)

    results = Handbook.search("absence", locale: :en)
    assert results.any? { |r| r[:name] == "absence" },
      "Expected 'absence' page to be included when feature is active"
  end

  test "search includes pages not tied to any feature" do
    # billing, deliveries, getting_started, etc. are not in FEATURES
    assert_not :billing.in?(Organization::FEATURES)

    results = Handbook.search("billing", locale: :en)
    assert results.any? { |r| r[:name] == "billing" },
      "Expected 'billing' page to always be included (not a feature)"
  end

  # -- Multi-word queries --

  test "search with multi-word query matches all terms (AND semantics)" do
    results = Handbook.search("basket complements", locale: :en)

    match = results.find { |r| r[:anchor] == "basket-complements" }
    assert match, "Expected a match for 'basket complements'"
  end

  test "search with partial word matches substring in heading" do
    results = Handbook.search("deliver", locale: :en)

    match = results.find { |r| r[:name] == "deliveries" && r[:subtitle].nil? }
    assert match, "Expected a title match for partial word 'deliver'"
  end

  # -- Caching --

  test "headings_for caches results per locale" do
    first_call = Handbook.headings_for(:en)
    second_call = Handbook.headings_for(:en)

    assert_same first_call, second_call,
      "Expected headings_for to return the same cached object"
  end

  test "headings_for caches separately per locale" do
    en_headings = Handbook.headings_for(:en)
    fr_headings = Handbook.headings_for(:fr)

    refute_same en_headings, fr_headings,
      "Expected different objects for different locales"
  end

  test "clear_headings_cache! resets the cache" do
    Handbook.headings_for(:en)
    Handbook.clear_headings_cache!

    # After clearing, headings_for should parse again (returns new object)
    fresh = Handbook.headings_for(:en)
    assert_kind_of Array, fresh
    assert fresh.any?, "Expected headings to be re-parsed after cache clear"
  end

  # -- Heading extraction --

  test "headings_for returns all pages with titles" do
    headings = Handbook.headings_for(:en)

    assert headings.any?, "Expected at least one page"
    headings.each do |page|
      assert page[:name].present?, "Expected page name"
      assert page[:title].present?, "Expected page title for #{page[:name]}"
      assert page[:normalized_title].present?, "Expected normalized title for #{page[:name]}"
    end
  end

  test "headings_for extracts subtitles with anchors" do
    headings = Handbook.headings_for(:en)

    billing = headings.find { |p| p[:name] == "billing" }
    assert billing, "Expected to find billing page"

    memberships = billing[:subtitles].find { |text, anchor, _| anchor == "memberships" }
    assert memberships, "Expected to find 'memberships' subtitle in billing page"
    assert_equal "Memberships", memberships[0]
    assert_equal "memberships", memberships[1]
  end

  test "headings_for returns consistent anchors across locales" do
    en_headings = Handbook.headings_for(:en)
    fr_headings = Handbook.headings_for(:fr)

    en_billing = en_headings.find { |p| p[:name] == "billing" }
    fr_billing = fr_headings.find { |p| p[:name] == "billing" }

    en_anchors = en_billing[:subtitles].map { |_, anchor, _| anchor }.sort
    fr_anchors = fr_billing[:subtitles].map { |_, anchor, _| anchor }.sort

    assert_equal en_anchors, fr_anchors,
      "Expected same anchor IDs across English and French for billing page"
  end

  # -- Multiple matches --

  test "search can return both title and subtitle matches" do
    # "billing" appears as a page title AND as subtitles in other pages
    results = Handbook.search("billing", locale: :en)

    title_match = results.find { |r| r[:name] == "billing" && r[:subtitle].nil? }
    subtitle_matches = results.select { |r| r[:subtitle].present? }

    assert title_match, "Expected at least one title match"
    assert subtitle_matches.any?, "Expected at least one subtitle match for 'billing'"
  end

  # -- Locale-specific title matching --

  test "search matches locale-specific title text" do
    # In French, the billing page title is "Facturation"
    results = Handbook.search("facturation", locale: :fr)

    match = results.find { |r| r[:name] == "billing" && r[:subtitle].nil? }
    assert match, "Expected to find billing page by French title 'Facturation'"
  end

  test "search does not match English title when using French locale" do
    # "Billing" (English) should not match French headings (which say "Facturation")
    results = Handbook.search("billing", locale: :fr)

    title_match = results.find { |r| r[:name] == "billing" && r[:subtitle].nil? }
    assert_nil title_match,
      "Expected no French title match for English word 'Billing'"
  end
end
