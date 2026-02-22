# frozen_string_literal: true

require "test_helper"

class SearchHelperTest < ActiveSupport::TestCase
  include SearchHelper
  include Rails.application.routes.url_helpers

  test "highlight_search wraps matching substring in mark tags" do
    result = highlight_search("Jean Dupont", "dupont")
    assert_equal "Jean <mark>Dupont</mark>", result
  end

  test "highlight_search is case-insensitive" do
    result = highlight_search("Jean Dupont", "DUPONT")
    assert_equal "Jean <mark>Dupont</mark>", result
  end

  test "highlight_search is accent-insensitive" do
    result = highlight_search("René Müller", "rene")
    assert_equal "<mark>René</mark> Müller", result
  end

  test "highlight_search preserves original accents and casing in output" do
    result = highlight_search("Café Zürich", "cafe")
    assert_equal "<mark>Café</mark> Zürich", result
  end

  test "highlight_search handles multiple matches" do
    result = highlight_search("test foo test bar test", "test")
    assert_equal "<mark>test</mark> foo <mark>test</mark> bar <mark>test</mark>", result
  end

  test "highlight_search returns html_safe string" do
    result = highlight_search("Jean Dupont", "dupont")
    assert result.html_safe?
  end

  test "highlight_search escapes HTML in text" do
    result = highlight_search("<script>alert('xss')</script> Dupont", "dupont")
    assert_includes result, "&lt;script&gt;"
    assert_includes result, "<mark>Dupont</mark>"
  end

  test "highlight_search returns escaped text when query is blank" do
    result = highlight_search("Jean Dupont", "")
    assert_equal "Jean Dupont", result
    assert result.html_safe?
  end

  test "highlight_search returns escaped text when query is nil" do
    result = highlight_search("Jean Dupont", nil)
    assert_equal "Jean Dupont", result
  end

  test "highlight_search returns empty string for blank text" do
    result = highlight_search("", "test")
    assert_equal "", result
    assert result.html_safe?
  end

  test "highlight_search returns empty string for nil text" do
    result = highlight_search(nil, "test")
    assert_equal "", result
  end

  test "highlight_search ignores queries shorter than 2 characters" do
    result = highlight_search("Jean Dupont", "J")
    assert_equal "Jean Dupont", result
  end

  test "highlight_search handles substring matching" do
    result = highlight_search("Jean-Pierre Dupont", "upon")
    assert_equal "Jean-Pierre D<mark>upon</mark>t", result
  end

  test "highlight_search handles accented query matching unaccented text" do
    result = highlight_search("Cafe Normal", "café")
    assert_equal "<mark>Cafe</mark> Normal", result
  end

  test "highlight_search with numeric content" do
    result = highlight_search("Invoice #1234 for member", "1234")
    assert_equal "Invoice #<mark>1234</mark> for member", result
  end

  test "highlight_search matches through thousands separators" do
    result = highlight_search("CHF 1'416.00", "14")
    assert_equal "CHF <mark>1&#39;4</mark>16.00", result
  end

  test "highlight_search matches through dots in formatted numbers" do
    result = highlight_search("CHF 1.416,00", "14")
    assert_equal "CHF <mark>1.4</mark>16,00", result
  end

  test "highlight_search matches full formatted amount" do
    result = highlight_search("CHF 1'416.00", "1416")
    assert_equal "CHF <mark>1&#39;416</mark>.00", result
  end

  test "highlight_search handles overlapping potential matches" do
    result = highlight_search("aaaa", "aaa")
    # Should find at least one match and not crash
    assert_includes result, "<mark>"
  end

  # --- Multi-word highlighting ---

  test "highlight_search highlights each word independently" do
    result = highlight_search("Jean Dupont Lausanne", "dup laus")
    assert_equal "Jean <mark>Dup</mark>ont <mark>Laus</mark>anne", result
  end

  test "highlight_search highlights multiple words in any order" do
    result = highlight_search("Jean Dupont Lausanne", "laus dup")
    assert_equal "Jean <mark>Dup</mark>ont <mark>Laus</mark>anne", result
  end

  test "highlight_search merges overlapping highlights from different terms" do
    result = highlight_search("foobar", "foo oob")
    # "foo" matches 0-3, "oob" matches 1-4 → merged to 0-4
    assert_equal "<mark>foob</mark>ar", result
  end

  test "highlight_search highlights short numeric terms (2 chars)" do
    result = highlight_search("Invoice 42 for member", "42")
    assert_equal "Invoice <mark>42</mark> for member", result
  end

  test "highlight_search with mixed long and short numeric terms" do
    result = highlight_search("Jean Dupont #42", "dupont 42")
    assert_equal "Jean <mark>Dupont</mark> #<mark>42</mark>", result
  end

  test "highlight_search highlights 2-char alphabetic terms" do
    result = highlight_search("Jean Dupont de Lausanne", "dupont de laus")
    assert_equal "Jean <mark>Dupont</mark> <mark>de</mark> <mark>Laus</mark>anne", result
  end

  test "highlight_search skips terms shorter than 2 chars" do
    result = highlight_search("Jean Dupont A Lausanne", "dupont a laus")
    # "a" is < 2 chars so it should be skipped
    assert_equal "Jean <mark>Dupont</mark> A <mark>Laus</mark>anne", result
  end

  test "highlight_search with multi-word query where one term has no match" do
    result = highlight_search("Jean Dupont", "dupont paris")
    # Only "dupont" matches, "paris" doesn't — still highlights what matches
    assert_equal "Jean <mark>Dupont</mark>", result
  end

  test "highlight_search with adjacent highlights merges them" do
    result = highlight_search("abcdef", "abc def")
    assert_equal "<mark>abcdef</mark>", result
  end

  # --- Handbook search result rendering ---

  test "search_result_for_handbook title match has book-open icon" do
    entry = { name: "billing", title: "Billing", subtitle: nil, anchor: nil, page_title: nil }
    result = search_result_for_handbook(entry, "billing")

    assert_equal "book-open", result[:icon_name]
  end

  test "search_result_for_handbook title match uses page title as title" do
    entry = { name: "billing", title: "Billing", subtitle: nil, anchor: nil, page_title: nil }
    result = search_result_for_handbook(entry, "billing")

    assert_equal "Billing", result[:title]
    assert_empty result[:subtitle_parts]
  end

  test "search_result_for_handbook title match links to page without anchor" do
    entry = { name: "billing", title: "Billing", subtitle: nil, anchor: nil, page_title: nil }
    result = search_result_for_handbook(entry, "billing")

    assert_equal handbook_page_path("billing"), result[:url]
  end

  test "search_result_for_handbook subtitle match uses subtitle text as title" do
    entry = { name: "deliveries", title: "Deliveries", subtitle: "Delivery cycles", anchor: "delivery-cycles", page_title: "Deliveries" }
    result = search_result_for_handbook(entry, "delivery cycles")

    assert_equal "Delivery cycles", result[:title]
  end

  test "search_result_for_handbook subtitle match shows highlighted page title in subtitle_parts" do
    entry = { name: "deliveries", title: "Deliveries", subtitle: "Delivery cycles", anchor: "delivery-cycles", page_title: "Deliveries" }
    result = search_result_for_handbook(entry, "deliver")

    assert_equal 1, result[:subtitle_parts].size
    assert_includes result[:subtitle_parts].first, "<mark>"
    assert_includes result[:subtitle_parts].first, "Deliver"
  end

  test "search_result_for_handbook subtitle match links to page with anchor" do
    entry = { name: "billing", title: "Billing", subtitle: "Share capital", anchor: "share-capital", page_title: "Billing" }
    result = search_result_for_handbook(entry, "share capital")

    assert_equal handbook_page_path("billing", anchor: "share-capital"), result[:url]
  end

  test "search_result_for_handbook does not include state keys" do
    entry = { name: "billing", title: "Billing", subtitle: nil, anchor: nil, page_title: nil }
    result = search_result_for_handbook(entry, "billing")

    assert_not result.key?(:state)
    assert_not result.key?(:state_label)
  end

  test "highlight_search matches through hyphens in city names" do
    result = highlight_search("La Chaux-de-Fonds", "chaux-de-fonds")
    assert_equal "La <mark>Chaux-de-Fonds</mark>", result
  end

  test "highlight_search matches hyphenated query against unhyphenated text" do
    result = highlight_search("2300 La Chaux-de-Fonds", "chaux-de-fonds")
    assert_equal "2300 La <mark>Chaux-de-Fonds</mark>", result
  end

  # --- Locale-independent highlighting ---

  test "highlight_search highlights German umlauts regardless of locale" do
    I18n.with_locale(:de) do
      assert_equal "<mark>Bätt</mark>ig", highlight_search("Bättig", "batt")
      assert_equal "<mark>Blät</mark>tler", highlight_search("Blättler", "blat")
      assert_equal "<mark>Müll</mark>er", highlight_search("Müller", "mull")
      assert_equal "8000 <mark>Zür</mark>ich", highlight_search("8000 Zürich", "zur")
    end
  end

  test "highlight_search produces same results across all locales" do
    text = "Bättig Romina und Elmar"
    query = "batt"

    results = %i[en fr de it nl].map { |locale|
      I18n.with_locale(locale) { highlight_search(text, query) }
    }

    assert results.all? { |r| r == results.first },
      "Expected same highlight across locales, got: #{results.inspect}"
    assert_includes results.first, "<mark>"
  end
end
