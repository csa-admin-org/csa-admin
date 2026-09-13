# frozen_string_literal: true

require "test_helper"

class Support::MessageFormatTest < ActiveSupport::TestCase
  test "returns nil for blank" do
    assert_nil Support::MessageFormat.to_html(nil)
    assert_nil Support::MessageFormat.to_html("  ")
  end

  test "autolinks urls" do
    html = Support::MessageFormat.to_html("See https://example.com/handbook")

    assert_includes html, 'href="https://example.com/handbook"'
  end

  test "renders lists" do
    html = Support::MessageFormat.to_html("- one\n- two")

    assert_includes html, "<ul>"
    assert_includes html, "<li>one</li>"
  end

  test "turns single newlines into line breaks" do
    html = Support::MessageFormat.to_html("Salut Thibaud,\nMerci.\n\nPeux-tu m'aider?")

    assert_includes html, "Salut Thibaud,<br"
    assert_includes html, "Merci."
    assert_includes html, "Peux-tu m"
    assert_equal 2, html.scan("<p>").size
  end

  test "blank lines become separate paragraphs" do
    html = Support::MessageFormat.to_html(<<~TEXT)
      Salut Thibaud,

      Merci beaucoup pour cette amélioration.
      Je prend le temps seulement maintenant.

      Peux-tu m'aider?
    TEXT

    assert_includes html, "Salut Thibaud,"
    assert_includes html, "Merci beaucoup"
    assert_includes html, "<br"
    assert_equal 3, html.scan("<p>").size
  end

  test "keeps mid-body blockquotes" do
    html = Support::MessageFormat.to_html("Salut\n\n> cited\n\nAnswer")

    assert_includes html, "<blockquote>"
    assert_includes html, "cited"
    assert_includes html, "Answer"
  end

  test "fences liquid snippets as code" do
    body = <<~TEXT
      comme cela:
      {% if member.salary_basket %}
      2
      {% else %}
      {{ membership.baskets
      | round }}
      {% endif %}
      Deuxièmement
    TEXT
    html = Support::MessageFormat.to_html(body)

    assert_includes html, "<pre>"
    assert_includes html, "{% if member.salary_basket %}"
    assert_includes html, "| round }}"
    assert_match(%r{</pre>.*Deuxièmement}m, html)
  end

  test "keeps a split liquid if else endif as one fence" do
    nbsp = "\u00a0"
    body = <<~TEXT
      comme cela:
      {% if membership.started_fy_month > 4 or membership.started_fy_month == 4 and membership.started_day >= 1 %}
      #{nbsp} 0

      {% else %}
      {{ membership.baskets
      divided_by: membership.full_year_deliveries
      times: membership.full_year_absences_included
      round }}
      {% endif %}
      Quelle est la date?
    TEXT
    html = Support::MessageFormat.to_html(body)

    assert_equal 1, html.scan("<pre").size
    assert_includes html, "{% else %}"
    assert_includes html, "divided_by:"
    assert_match(%r{</pre>.*Quelle est la date}m, html)
  end

  test "escapes html" do
    html = Support::MessageFormat.to_html("Hi <script>alert(1)</script>")

    assert_not_includes html, "<script>"
    assert_includes html, "alert(1)"
  end
end
