# frozen_string_literal: true

require "test_helper"

class Support::MessageHtmlTest < ActiveSupport::TestCase
  test "drops leftover markdown image next to a link" do
    html = <<~HTML
      <p>![image]
      <a href="https://admin.acme.test/invoices">https://admin.acme.test/invoices</a></p>
    HTML

    rewritten = Support::MessageHtml.rewrite(html)

    assert_not_includes rewritten, "!["
    assert_includes rewritten, "https://admin.acme.test/invoices"
  end

  test "repairs mojibake and cuts gmail leftover" do
    html = <<~HTML
      <p>Merci pour la rÃ©solution du problÃ¨me!</p>
      <p>Le 06.04.26 Ã&nbsp; 23:26, info@csa-admin.org a Ã©critÂ :</p>
    HTML

    rewritten = Support::MessageHtml.rewrite(html)

    assert_includes rewritten, "résolution"
    assert_not_includes rewritten, "Ã"
    assert_not_includes rewritten, "a écrit"
    assert_not_includes rewritten, "info@csa-admin.org"
  end

  test "cuts apple mail dump including gray pre boxes" do
    html = <<~HTML
      <p>Oui ça a été corrigé.</p>
      <pre><code>  Merci</code></pre>
      <p>Le 28.12.2025 à 21:12, info@csa-admin.org a écrit :</p>
      <blockquote><p>Hey,</p></blockquote>
      <blockquote><pre><code>Merci pour ton retour :)</code></pre></blockquote>
    HTML

    rewritten = Support::MessageHtml.rewrite(html)

    assert_includes rewritten, "corrigé"
    assert_not_includes rewritten, "Merci pour ton retour"
    assert_not_includes rewritten, "a écrit"
    assert_not_includes rewritten, "<blockquote"
  end

  test "keeps mid-body citations" do
    html = <<~HTML
      <p>Salut,</p>
      <blockquote><p>Ce que j’ai selectionné</p></blockquote>
      <p>C’est deux fonctionnalités.</p>
    HTML

    rewritten = Support::MessageHtml.rewrite(html)

    assert_includes rewritten, "Ce que j’ai selectionné"
    assert_includes rewritten, "deux fonctionnalités"
  end

  test "merges split liquid fences and kramdown tables" do
    html = <<~HTML
      <p>Voilà:</p>
      <pre><code>{% if membership.started_fy_month &gt; 4 %}</code></pre>
      <p>&nbsp; 0</p>
      <pre><code>{% else %}</code></pre>
      <table><tr>
        <td>{{ membership.baskets</td>
        <td>divided_by: membership.full_year_deliveries</td>
        <td>round }}</td>
      </tr></table>
      <pre><code>{% endif %}</code></pre>
      <p>Quelle est la date?</p>
    HTML

    rewritten = Support::MessageHtml.rewrite(html)

    code = Nokogiri::HTML.fragment(rewritten).at("pre").text

    assert_equal 1, rewritten.scan("<pre").size
    assert_equal <<~CODE.strip, code.strip
      {% if membership.started_fy_month > 4 %}
        0
      {% else %}
        {{ membership.baskets | divided_by: membership.full_year_deliveries | round }}
      {% endif %}
    CODE
    assert_not_includes rewritten, "<table"
    assert_includes rewritten, "Quelle est la date?"
  end

  test "merges liquid left as a text node after action text strips tables" do
    html = <<~HTML
      <div class="trix-content">
        <pre><code>{% if membership.started_fy_month &gt; 4 %}</code></pre>
        <p>&nbsp; 0</p>
        <pre><code>{% else %}</code></pre>
        {{ membership.baskets divided_by: membership.full_year_deliveries round }}
        <pre><code>{% endif %}</code></pre>
        <p>Quelle est la date?</p>
      </div>
    HTML

    rewritten = Support::MessageHtml.rewrite(html)
    code = Nokogiri::HTML.fragment(rewritten).at("pre").text

    assert_equal 1, rewritten.scan("<pre").size
    assert_includes code, "{{ membership.baskets | divided_by: membership.full_year_deliveries | round }}"
  end

  test "reconstructs mail.app liquid from the jsonl shape" do
    html = <<~HTML
      <pre><code>{% if membership.started_fy_month &gt; 4 or membership.started_fy_month == 4 and membership.started_day &gt;= 1 %}

  0

{% else %}

  {{ membership.baskets | divided_by: membership.full_year_deliveries | times: membership.full_year_absences_included | round }}

{% endif %}</code></pre>
    HTML

    code = Nokogiri::HTML.fragment(Support::MessageHtml.rewrite(html)).at("pre").text

    assert_equal <<~CODE.strip, code.strip
      {% if membership.started_fy_month > 4 or membership.started_fy_month == 4 and membership.started_day >= 1 %}
        0
      {% else %}
        {{ membership.baskets | divided_by: membership.full_year_deliveries | times: membership.full_year_absences_included | round }}
      {% endif %}
    CODE
  end

  test "does not merge unrelated liquid snippets" do
    html = <<~HTML
      <pre><code>{% if basket %}ok{% endif %}</code></pre>
      <pre><code>{% content id: "intro" %}{% endcontent %}</code></pre>
    HTML

    rewritten = Support::MessageHtml.rewrite(html)

    assert_equal 2, rewritten.scan("<pre").size
  end
end
