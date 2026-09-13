# frozen_string_literal: true

require "test_helper"

class Support::Utf8Test < ActiveSupport::TestCase
  test "repairs utf8 read as latin1" do
    assert_equal "résolution", Support::Utf8.repair("rÃ©solution")
    assert_equal "ça a été", Support::Utf8.repair("Ã§a a Ã©tÃ©")
    assert_equal "écrit", Support::Utf8.repair("Ã©crit")
  end

  test "keeps curly apostrophes next to mojibake" do
    source = "Oui Ã§a a Ã©tÃ© corrigÃ©. Je m’en suis aperÃ§u."

    assert_equal "Oui ça a été corrigé. Je m’en suis aperçu.", Support::Utf8.repair(source)
  end

  test "leaves valid utf8 alone" do
    assert_equal "écriture", Support::Utf8.repair("écriture")
  end

  test "repairs mixed valid pairs and degenerated a-grave" do
    source = "Le 06.04.26 Ã  23:26 a Ã©crit"

    assert_equal "Le 06.04.26 à  23:26 a écrit", Support::Utf8.repair(source)
  end

  test "repairs text nodes in a fragment" do
    fragment = Nokogiri::HTML::DocumentFragment.parse("<p>rÃ©solution</p>")

    Support::Utf8.repair_fragment!(fragment)

    assert_equal "résolution", fragment.text.strip
  end
end
