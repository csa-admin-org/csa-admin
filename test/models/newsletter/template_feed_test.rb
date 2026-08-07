# frozen_string_literal: true

require "test_helper"

class Newsletter::TemplateFeedTest < ActiveSupport::TestCase
  test "parses public attribute on content blocks" do
    template = Newsletter::Template.new(content: <<~LIQUID)
      {% content id: 'main', title: "Title", public: true %}{% endcontent %}
      {% content id: 'side', public: false %}{% endcontent %}
      {% content id: 'other' %}{% endcontent %}
    LIQUID

    blocks = template.content_blocks["en"]
    assert_equal [ true, false, false ], blocks.map(&:public?)
    assert_equal %w[main], template.public_content_block_ids

    form_blocks = template.blocks.index_by(&:block_id)
    assert form_blocks["main"].public_content?
    assert_not form_blocks["main"].public_feed?
    assert_not form_blocks["side"].public_content?
    assert_not form_blocks["other"].public_content?

    template.feed_enabled = true
    feed_blocks = template.blocks.index_by(&:block_id)
    assert feed_blocks["main"].public_content?
    assert feed_blocks["main"].public_feed?
    assert_not feed_blocks["side"].public_content?
    assert feed_blocks["side"].public_feed?
  end

  test "rejects invalid public attribute values" do
    template = Newsletter::Template.new(
      title: "T",
      content: "{% content id: 'main', public: maybe %}{% endcontent %}")

    assert_not template.valid?
    assert template.errors[:content_en].any?
  end

  test "feed_enabled requires at least one public content block" do
    template = newsletter_templates(:simple)
    template.feed_enabled = true

    assert_not template.valid?
    assert_includes template.errors[:feed_enabled],
      "requires at least one content block marked with public: true"
  end

  test "feed_enabled is valid with a public content block" do
    template = newsletter_templates(:simple)
    template.content = <<~LIQUID
      {% content id: 'main', public: true %}{% endcontent %}
    LIQUID
    template.feed_enabled = true

    assert template.valid?
  end

  test "email rendering ignores public attribute" do
    template = Newsletter::Template.new(content: <<~LIQUID)
      {% content id: 'main', title: "Content Title", public: true %}
      Example Text {{ member.name }}
      {% endcontent %}
    LIQUID
    template.liquid_data_preview_yamls = {
      "en" => <<~YAML
        member:
          name: Bob Dae
        subject: Newsletter
      YAML
    }

    mail = template.mail_preview("en")
    assert_includes mail, "Content Title</h2>"
    assert_includes mail, "Example Text Bob Dae"
  end

  test "feed_url present only when enabled" do
    template = newsletter_templates(:simple)
    assert_nil template.feed_url

    template.update!(
      content: "{% content id: 'main', public: true %}{% endcontent %}",
      feed_enabled: true)

    assert_match %r{\Ahttps://members\.acme\.test/newsletters\.atom\?template_id=#{template.id}\z}, template.feed_url
  end

  test "next_delivery default marks editorial blocks public but keeps feed disabled" do
    Newsletter::Template.create_defaults!

    next_delivery = Newsletter::Template.title_eq("Next delivery").first!
    assert_not next_delivery.feed_enabled?
    assert_equal %w[intro events recipe], next_delivery.public_content_block_ids

    simple = Newsletter::Template.title_eq("Simple text").first!
    assert_not simple.feed_enabled?
    assert_empty simple.public_content_block_ids
  end
end
