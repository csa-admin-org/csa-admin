# frozen_string_literal: true

require "test_helper"

class Support::ReplyQuoteTest < ActiveSupport::TestCase
  test "strips a trailing cited thread from html" do
    html = <<~HTML
      <p>Salut Marco,</p>
      <p>Est-ce que le numéro est le même?</p>
      <blockquote>
        <p>On 24 Jun 2026, at 20:53, Jane wrote:</p>
        <p>Hello, original request</p>
      </blockquote>
    HTML

    cleaned = Support::ReplyQuote.strip_html(html)

    assert_includes cleaned, "Salut Marco"
    assert_not_includes cleaned, "original request"
    assert_not_includes cleaned, "blockquote"
  end

  test "strips consecutive trailing blockquotes" do
    html = <<~HTML
      <p>Merci :)</p>
      <blockquote><p>On 24 Jun 2026, at 21:16, Jane wrote:</p></blockquote>
      <blockquote><p>Facture n 1167</p></blockquote>
      <blockquote>
        <blockquote>
          <p>Salut Marco,</p>
        </blockquote>
      </blockquote>
    HTML

    cleaned = Support::ReplyQuote.strip_html(html)

    assert_includes cleaned, "Merci :)"
    assert_not_includes cleaned, "Facture"
    assert_not_includes cleaned, "Salut Marco"
  end

  test "keeps mid-body citations" do
    html = <<~HTML
      <p>Salut,</p>
      <blockquote>
        <p>Ce que j’ai selectionné</p>
      </blockquote>
      <p>C’est deux fonctionnalités différentes.</p>
      <blockquote>
        <p>Deuxièmement, je ne vois pas</p>
      </blockquote>
      <p>Oui, mais c’est possible seulement une fois.</p>
    HTML

    cleaned = Support::ReplyQuote.strip_html(html)

    assert_includes cleaned, "Ce que j’ai selectionné"
    assert_includes cleaned, "Deuxièmement"
    assert_includes cleaned, "Oui, mais"
  end

  test "strips a trailing proton original message separator" do
    html = <<~HTML
      <p>À demain :)</p>
      <p>——– Original Message ——–</p>
    HTML

    cleaned = Support::ReplyQuote.strip_html(html)

    assert_includes cleaned, "À demain"
    assert_not_includes cleaned, "Original Message"
  end

  test "strips trailing markdown quotes from text" do
    text = <<~TEXT
      Merci :)

      > On 24 Jun 2026, at 20:53, Jane wrote:
      > Hello, original request
    TEXT

    cleaned = Support::ReplyQuote.strip_text(text)

    assert_equal "Merci :)", cleaned
  end

  test "keeps a cid image in the new reply" do
    html = "<div>See <img src='cid:shot@mail' /></div>"

    cleaned = Support::ReplyQuote.strip_html(html)

    assert_includes cleaned, "cid:shot@mail"
    assert_includes cleaned, "See"
  end

  test "keeps mid-body markdown quotes" do
    text = <<~TEXT
      Salut,

      > Ce que j’ai selectionné

      C’est deux fonctionnalités.

      > Deuxièmement

      Oui, mais c’est possible.
    TEXT

    cleaned = Support::ReplyQuote.strip_text(text)

    assert_includes cleaned, "> Ce que j’ai selectionné"
    assert_includes cleaned, "> Deuxièmement"
    assert_includes cleaned, "Oui, mais c’est possible."
  end

  test "cuts a gmail leftover after the new reply" do
    html = <<~HTML
      <p>Salut Thibaud</p>
      <p>Anita</p>
      <p>Le&nbsp;ven. 24 avr. 2026 à&nbsp;15:10, info@csa-admin.org <a href="mailto:info@csa-admin.org">info@csa-admin.org</a> a écrit&nbsp;:</p>
    HTML

    cleaned = Support::ReplyQuote.strip_html(html)

    assert_includes cleaned, "Anita"
    assert_not_includes cleaned, "a écrit"
    assert_not_includes cleaned, "info@csa-admin.org"
  end

  test "cuts a gmail leftover glued into the same paragraph" do
    html = <<~HTML
      <p>Top ça a marché merci beaucoup!</p>
      <p>Le&nbsp;jeu. 12 mars 2026 à&nbsp;17:24, info@csa-admin.org <a href="mailto:info@csa-admin.org">info@csa-admin.org</a> a écrit&nbsp;:
      Salut Justine,</p>
      <p>Ce n’est pas un cas de figure facilement supporté.</p>
    HTML

    cleaned = Support::ReplyQuote.strip_html(html)

    assert_includes cleaned, "marché"
    assert_not_includes cleaned, "a écrit"
    assert_not_includes cleaned, "Salut Justine"
    assert_not_includes cleaned, "cas de figure"
  end

  test "cuts an apple mail hat geschrieben leftover" do
    html = <<~HTML
      <p>I am changing now all the cycles again.</p>
      <p>Am Dienstag, 6. Januar 2026 um 09:30:31 +01:00, hat &lt;info@grundnahrig.ch&gt; geschrieben:</p>
      <p>ah and i already received 2 emails</p>
    HTML

    cleaned = Support::ReplyQuote.strip_html(html)

    assert_includes cleaned, "changing now"
    assert_not_includes cleaned, "geschrieben"
    assert_not_includes cleaned, "already received"
  end

  test "cuts a date-first french leftover" do
    html = <<~HTML
      <p>Parfait, merci.</p>
      <p>18 août 2026 à 16:07 “Thibaud” <a href="mailto:info@csa-admin.org">info@csa-admin.org</a> a écrit:
      Salut Paola,</p>
      <p>Oui, il faut pour cela déactiver son panier.</p>
    HTML

    cleaned = Support::ReplyQuote.strip_html(html)

    assert_includes cleaned, "Parfait"
    assert_not_includes cleaned, "a écrit"
    assert_not_includes cleaned, "Salut Paola"
  end

  test "cuts mojibake apple mail dumps" do
    html = <<~HTML
      <p>Oui Ã§a a Ã©tÃ© corrigÃ©!</p>
      <pre><code>  Merci</code></pre>
      <p>Le 28.12.2025 Ã  21:12, info@csa-admin.org a Ã©critÂ :</p>
      <blockquote><p>Hey,</p></blockquote>
      <blockquote><pre><code>quoted thread</code></pre></blockquote>
    HTML

    cleaned = Support::ReplyQuote.strip_html(html)

    assert_includes cleaned, "corrigé"
    assert_not_includes cleaned, "quoted thread"
    assert_not_includes cleaned, "a écrit"
  end

  test "strips a trailing operator signature from html" do
    html = <<~HTML
      <p>Voici</p>
      <p>++</p>
      <p>Thibaud</p>
    HTML

    with_env("ULTRA_ADMIN_NAME" => "Thibaud") do
      cleaned = Support::ReplyQuote.strip_html(html)

      assert_includes cleaned, "Voici"
      assert_not_includes cleaned, "++"
      assert_not_includes cleaned, "Thibaud"
    end
  end

  test "strips a trailing operator signature from text" do
    with_env("ULTRA_ADMIN_NAME" => "Thibaud") do
      assert_equal "Voici", Support::ReplyQuote.strip_text("Voici\n\n++\nThibaud")
    end
  end
end
