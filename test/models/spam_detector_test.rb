# frozen_string_literal: true

require "test_helper"

class SpamDetectorTest < ActiveSupport::TestCase
  def spam?(member)
    SpamDetector.spam?(member)
  end

  test "detects too long note" do
    member = Member.new(note: "fobar" * 1000 + "A")
    assert_equal true, spam?(member)
  end

  test "detects too long food note" do
    member = Member.new(food_note: "fobar" * 1000 + "A")
    assert_equal true, spam?(member)
  end

  test "detects duplicated long texts" do
    member = Member.new(
      note:
        "Bonjour,\r\n" \
        "\r\n" \
        "Avez-vous un problème d'E-Réputation ? Avis/liens négatifs.\r\n" \
        "\r\n" \
        "Un expert me contacte : http://foo.bar\r\n" \
        "\r\n" \
        "Cordialement,\r\n" \
        "\r\n" \
        "L'équipe E-Réputation",
      come_from:
        "Bonjour," \
        "Avez-vous un problème d'E-Réputation ? Avis/liens négatifs." \
        "Un expert me contacte : http://foo.bar" \
        "Cordialement," \
        "L'équipe E-Réputation")
    assert_equal true, spam?(member)

    assert_includes member.note, " "
    assert_includes member.come_from, " "
  end

  test "skips duplicated short texts" do
    member = Member.new(
      note: "Merci  ",
      come_from: "Merci")
    assert_equal false, spam?(member)
  end

  test "detects wrong zip" do
    member = Member.new(zip: "153535")
    assert_equal true, spam?(member)
  end

  test "detects cyrillic address" do
    member = Member.new(address: "РњРѕСЃРєРІР°")
    assert_equal true, spam?(member)
  end

  test "detects cyrillic city" do
    member = Member.new(city: "РњРѕСЃРєРІР°")
    assert_equal true, spam?(member)
  end

  test "detects cyrillic come_from" do
    member = Member.new(come_from: "Р РѕСЃСЃРёСЏ")
    assert_equal true, spam?(member)
  end

  test "detects non native language text" do
    member = Member.new(note: "¿Está buscando una interfaz de contabilidad en la nube que haga que el funcionamiento de su empresa sea fácil, rápido y seguro?")
    assert_equal true, spam?(member)
  end

  test "ignores blank text" do
    member = Member.new(food_note: "")
    assert_equal false, spam?(member)
  end

  test "ignores short text" do
    member = Member.new(food_note: "YEAH ROCK ON!")
    assert_equal false, spam?(member)
  end

  test "accepts native language text" do
    member = Member.new(note: "Je me réjouis vraiment de recevoir mon panier!" * 3)
    assert_equal false, spam?(member)
  end

  test "allowed country" do
    ENV["ALLOWED_COUNTRY_CODES"] = "CH,FR"
    member = Member.new(country_code: "CH")
    assert_equal false, spam?(member)
  ensure
    ENV["ALLOWED_COUNTRY_CODES"] = nil
  end

  test "allowed countries not enabled" do
    ENV["ALLOWED_COUNTRY_CODES"] = nil
    member = Member.new(country_code: "VG")
    assert_equal false, spam?(member)
  end

  test "non allowed country" do
    ENV["ALLOWED_COUNTRY_CODES"] = "CH,FR"
    member = Member.new(country_code: "VG")
    assert_equal true, spam?(member)
  ensure
    ENV["ALLOWED_COUNTRY_CODES"] = nil
  end
end
