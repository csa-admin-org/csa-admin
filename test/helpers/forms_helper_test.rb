# frozen_string_literal: true

require "test_helper"

class FormsHelperTest < ActionView::TestCase
  include TooltipHelper

  def icon(_name, **)
    content_tag(:svg, nil, class: "eye-icon")
  end

  test "newsletter_block_content_hint uses liquid hint for private blocks" do
    block = Newsletter::Block.new(block_id: "main", template_id: 1, public_content: false)

    hint = newsletter_block_content_hint(block)

    assert_includes hint, "Liquid"
    assert_not_includes hint, "Public content"
    assert_not_includes hint, "public feed"
  end

  test "newsletter_block_content_hint uses liquid hint for public blocks when feed is off" do
    block = Newsletter::Block.new(
      block_id: "intro",
      template_id: 9,
      public_content: true,
      public_feed: false)

    hint = newsletter_block_content_hint(block)

    assert_includes hint, "Liquid"
    assert_not_includes hint, "Public content"
    assert_not_includes hint, "public feed"
  end

  test "newsletter_block_content_hint marks public blocks when feed is on" do
    block = Newsletter::Block.new(
      block_id: "intro",
      template_id: 9,
      public_content: true,
      public_feed: true)

    hint = newsletter_block_content_hint(block)

    assert_includes hint, "Public content"
    assert_includes hint, "public feed"
    assert_includes hint, "member"
    assert_includes hint, "/handbook/newsletters#feed"
    assert_includes hint, "public feed after the newsletter is sent"
    assert_includes hint, 'data-controller="tooltip"'
    assert_includes hint, "eye-icon"
    assert_includes hint, 'role="button"'
    assert_not_includes hint, "<button"
    assert_not_includes hint, "public: true"
  end
end
