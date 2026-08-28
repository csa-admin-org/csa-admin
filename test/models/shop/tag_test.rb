# frozen_string_literal: true

require "test_helper"

class Shop::TagTest < ActiveSupport::TestCase
  test "display_name joins emoji and name" do
    tag = Shop::Tag.new(names: { "en" => "Bread" })

    assert_equal "Bread", tag.display_name

    tag.emoji = "🍞"
    assert_equal "🍞 Bread", tag.display_name
  end

  test "EMOJIS keeps farm glyphs as single entries" do
    assert_equal 78, Shop::Tag::EMOJIS.size
    assert_includes Shop::Tag::EMOJIS, "🥕"
    assert_includes Shop::Tag::EMOJIS, "🌶️"
    assert_includes Shop::Tag::EMOJIS, "🍋‍🟩"
    assert_includes Shop::Tag::EMOJIS, "🍄‍🟫"
    assert_includes Shop::Tag::EMOJIS, "🫜"
    assert_includes Shop::Tag::EMOJIS, "🫕"
    assert_includes Shop::Tag::EMOJIS, "🌰"
    assert_includes Shop::Tag::EMOJIS, "🎁"
    assert_includes Shop::Tag::EMOJIS, "❗"
    assert_includes Shop::Tag::EMOJIS, "⚕️"
    assert Shop::Tag::EMOJIS.none?(&:blank?)
  end
end
