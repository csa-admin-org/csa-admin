# frozen_string_literal: true

require "test_helper"

class Support::ForwardedQuoteTest < ActiveSupport::TestCase
  test "wraps an outlook forward as markdown quotes" do
    text = <<~TEXT
      Salut Thibaud, j’ai reçu ce courriel.

      Gérard

      De : Rage de Vert [mailto:info@ragedevert.ch]
      Envoyé : samedi 25 mai 2024 05:18
      À : donzeteissier@net2000.ch
      Objet : Email rejeté (HardBounce)

      L'email a été rejeté.
    TEXT

    wrapped = Support::ForwardedQuote.wrap(text)

    assert_includes wrapped, "Salut Thibaud"
    assert_includes wrapped, "> De : Rage de Vert [mailto:info@ragedevert.ch]"
    assert_includes wrapped, "> Objet : Email rejeté (HardBounce)"
    assert_includes wrapped, "> L'email a été rejeté."
    refute_includes wrapped.lines.first, ">"
  end

  test "unmashes a glued origine header" do
    text = "Bonne journée.\nRaphaël\n---------- Message d'origine ----------De : Rage de Vert <info@ragedevert.ch>À : raphael.coquoz@bluewin.chDate : 07.05.2026 11:08 CESTSujet : Nouvelle réinscription"

    wrapped = Support::ForwardedQuote.wrap(text)

    assert_includes wrapped, "> ---------- Message d'origine ----------"
    assert_includes wrapped, "> De : Rage de Vert <info@ragedevert.ch>"
    assert_includes wrapped, "> À : raphael.coquoz@bluewin.ch"
    assert_includes wrapped, "> Sujet : Nouvelle réinscription"
  end

  test "wraps an apple-mail cited original" do
    text = "Here is the answer\n\nOn Mon, Jane Doe <jane@org.ch> wrote:\nHello"

    wrapped = Support::ForwardedQuote.wrap(text)

    assert_includes wrapped, "Here is the answer"
    assert_includes wrapped, "> On Mon, Jane Doe <jane@org.ch> wrote:"
    assert_includes wrapped, "> Hello"
  end

  test "leaves a message without a forward alone" do
    text = "Salut Thibaud,\njuste une question sur les paniers."

    assert_equal text, Support::ForwardedQuote.wrap(text)
  end

  test "original? detects forwarded headers" do
    assert Support::ForwardedQuote.original?("De : Rage de Vert\nEnvoyé : samedi\nObjet : Bounce")
    assert Support::ForwardedQuote.original?("---------- Message d'origine ----------\nDe : A")
    refute Support::ForwardedQuote.original?("On 24 Jun 2026, at 20:53, Jane wrote:\nHello")
  end
end
