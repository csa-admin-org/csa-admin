# frozen_string_literal: true

require "test_helper"

class FormsHelperTest < ActionView::TestCase
  include ApplicationHelper
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

  test "mail_preview_iframe is sandboxed and reports height" do
    html = mail_preview_iframe("<p>hi</p>", id: "mail_preview_en")

    assert_includes html, "sandbox=\"allow-scripts allow-popups allow-popups-to-escape-sandbox\""
    refute_includes html, "allow-same-origin"
    assert_includes html, "id=\"mail_preview_en\""
    assert_includes html, "class=\"mail_preview\""
    assert_includes html, ApplicationHelper::MAIL_PREVIEW_HEIGHT_MESSAGE
    assert_includes html, ApplicationHelper::MAIL_PREVIEW_MEASURE_MESSAGE
  end

  test "mail_preview_srcdoc injects a height reporter before </body>" do
    srcdoc = mail_preview_srcdoc("<html><body><p>hi</p></body></html>")

    assert_includes srcdoc, ApplicationHelper::MAIL_PREVIEW_HEIGHT_MESSAGE
    assert_match %r{</script>\s*</body>}i, srcdoc
  end

  test "mail_preview_srcdoc wraps fragments that have no body tag" do
    srcdoc = mail_preview_srcdoc("<p>hi</p>")

    assert_includes srcdoc, "<!DOCTYPE html>"
    assert_includes srcdoc, "<p>hi</p>"
    assert_includes srcdoc, ApplicationHelper::MAIL_PREVIEW_HEIGHT_MESSAGE
  end

  test "catalog_price_placeholder drops trailing zeros" do
    assert_equal "20", catalog_price_placeholder(20.0)
    assert_equal "20.5", catalog_price_placeholder(20.5)
    assert_nil catalog_price_placeholder(nil)
  end

  test "catalog_price_form_value blanks a matching default including 0" do
    assert_nil catalog_price_form_value(20, 20.0)
    assert_nil catalog_price_form_value(0, 0)
    assert_equal 0, catalog_price_form_value(0, 4)
    assert_equal 32, catalog_price_form_value(32, 30)
    assert_nil catalog_price_form_value(nil, 20)
  end
end
