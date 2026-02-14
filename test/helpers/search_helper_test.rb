# frozen_string_literal: true

require "test_helper"

class SearchHelperTest < ActiveSupport::TestCase
  include SearchHelper

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

  test "highlight_search skips non-numeric short terms" do
    result = highlight_search("Jean Dupont de Lausanne", "dupont de laus")
    # "de" is a non-numeric short term, so it should be skipped
    assert_equal "Jean <mark>Dupont</mark> de <mark>Laus</mark>anne", result
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

  test "highlight_search matches through hyphens in city names" do
    result = highlight_search("La Chaux-de-Fonds", "chaux-de-fonds")
    assert_equal "La <mark>Chaux-de-Fonds</mark>", result
  end

  test "highlight_search matches hyphenated query against unhyphenated text" do
    result = highlight_search("2300 La Chaux-de-Fonds", "chaux-de-fonds")
    assert_equal "2300 La <mark>Chaux-de-Fonds</mark>", result
  end
end
