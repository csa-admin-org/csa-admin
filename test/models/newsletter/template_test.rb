# frozen_string_literal: true

require "test_helper"

class Newsletter::TemplateTest < ActiveSupport::TestCase
  test "audit content changes" do
    session = sessions(:master)
    Current.session = session
    template = newsletter_templates(:simple)

    assert_difference -> { Audit.count }, 1 do
      template.update!(content: "Hey {{ member.name }}")
    end

    audit = template.audits.last
    assert_equal session, audit.session
    assert_equal "Hey {{ member.name }}", audit.audited_changes["contents"].last["en"]
  end

  test "validate unique content block ids" do
    template = Newsletter::Template.new(content: <<~LIQUID)
      {% content id: 'main' %}{% endcontent %}
      {% content id: 'main' %}{% endcontent %}
    LIQUID

    assert_not template.valid?
    assert_includes template.errors[:content_en],
      "The IDs of the \"content\" blocks must be unique"
  end

  test "validate same content block ids for all languages" do
    org(languages: %w[en fr])
    template = Newsletter::Template.new(
      content_en: <<~LIQUID,
        {% content id: 'first' %}{% endcontent %}
        {% content id: 'second' %}{% endcontent %}
      LIQUID
      content_fr: <<~LIQUID)
        {% content id: 'first' %}{% endcontent %}
        {% content id: 'third' %}{% endcontent %}
      LIQUID

    assert_not template.valid?
    assert_includes template.errors[:content_en],
      "The IDs of the \"content\" blocks must be the same for all languages"
    assert_includes template.errors[:content_fr],
      "The IDs of the \"content\" blocks must be the same for all languages"
  end

  test "validate liquid syntax" do
    template = Newsletter::Template.new(content: "Hello {% foo %}")

    assert_not template.valid?
    assert_includes template.errors[:content_en], "Liquid syntax error: Unknown tag 'foo'"
  end

  test "validate content presence" do
    template = Newsletter::Template.new(content: "")

    assert_not template.valid?
    assert_includes template.errors[:content_en], "can't be blank"
  end

  test "validate content HTML syntax" do
    template = Newsletter::Template.new(content: "<p>Hello<//p>")

    assert_not template.valid?
    assert_includes template.errors[:content_en],
      "HTML error at line 1: Invalid first character of tag name"
  end

  test "list content blocks" do
    template = Newsletter::Template.new(content: <<~LIQUID)
      Hello {{ member.name }},

      {% content id: 'main', title: "Content Title" %}
      Example Text {{ member.name }}
        {% if member.email %}
          Hello {{ member.email }}
        {% endif %}
      {% endcontent %}

      <p>bla bla</p>

      {% content id: 'second', title: "Second Title" %}
      {% endcontent %}

      <p>bla bla</p>

      {% content id: 'third' %}
      <p>Third Content</p>
      {% endcontent %}

      <p>bla bla</p>
    LIQUID

    assert_equal %w[main second third], template.content_block_ids
    content_blocks = template.content_blocks["en"]
    assert_equal [ "Content Title", "Second Title", nil ], content_blocks.map(&:title)
    assert_equal [
      "<div>Example Text {{ member.name }}\n  {% if member.email  %}\n  Hello {{ member.email }}\n{% endif %}</div>",
      "<div></div>",
      "<div><p>Third Content</p></div>"
    ], content_blocks.map(&:raw_body)
  end

  test "mailpreview" do
    template = Newsletter::Template.new(content: <<~LIQUID)
      Hello {{ member.name }},

      {% content id: 'main', title: "Content Title" %}
      Example Text {{ member.name }}
      {% endcontent %}

      {% content id: 'second', title: "Second Title" %}
      {% endcontent %}

      {% content id: 'third' %}
      <p>Third Content</p>
      {% endcontent %}

      <p>bla bla</p>
    LIQUID

    template.liquid_data_preview_yamls = {
      "en" => <<~YAML
        member:
          name: Bob Dae
        subject: Newsletter
      YAML
    }

    mail = template.mail_preview("en")
    assert_includes mail, "Hello Bob Dae,"
    assert_includes mail, "Content Title</h2>"
    assert_includes mail, "Example Text Bob Dae"
    assert_not_includes mail, "Second Title/h2>"
    assert_includes mail, "Third Content</p>"
    assert_includes mail, "bla bla</p>"
  end

  test "send default simple template" do
    Newsletter::Template.create_defaults!
    template = Newsletter::Template.find_by!(title: "Simple text")
    newsletter = Newsletter.create!(
      template: template,
      audience: "member_state::active",
      subject: "Texte simple test",
      blocks_attributes: {
        "0" => { block_id: "text", content_en: "Hello {{ member.name }}" }
      })

    assert_difference -> { newsletter.deliveries.count }, 2 do
      perform_enqueued_jobs { newsletter.send! }
    end

    email = ActionMailer::Base.deliveries.first
    assert_equal "Texte simple test", email.subject
    mail_body = email.parts.map(&:body).join
    assert_includes mail_body, "Hello John Doe"
  end

  test "send default next delivery template" do
    travel_to "2024-01-01"
    Newsletter::Template.create_defaults!
    template = Newsletter::Template.find_by!(title: "Next delivery")
    newsletter = Newsletter.create!(
      template: template,
      audience: "member_state::active",
      subject: "Next delivery test",
      blocks_attributes: {
        "0" => { block_id: "intro", content_en: "Intro {{ member.name }}!" },
        "2" => { block_id: "events", content_en: "Fun marker" },
        "3" => { block_id: "recipe", content_en: "" }
      })

    assert_difference -> { newsletter.deliveries.count }, 2 do
      perform_enqueued_jobs { newsletter.send! }
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal "Next delivery test", email.subject
    mail_body = email.parts.map(&:body).join
    assert_includes mail_body, "Intro Jane Doe!"
    assert_not_includes mail_body, "Basket Contents"
    assert_includes mail_body, "Upcoming Events"
    assert_includes mail_body, "Fun marker"
    assert_not_includes mail_body, "Recipe"

    assert_includes mail_body, "Here are the upcoming activities where we still need people:"
    assert_includes mail_body, "Help with the harvest, Farm</li>"
    assert_includes mail_body, "Considering your current registrations, you still have\n2"
  end

  test "send default next delivery template (without activities)" do
    org(features: [])
    Newsletter::Template.create_defaults!
    template = Newsletter::Template.find_by!(title: "Next delivery")
    newsletter = Newsletter.create!(
      template: template,
      audience: "member_state::active",
      subject: "Next delivery test",
      blocks_attributes: {
        "0" => { block_id: "intro", content_en: "Hello" },
        "2" => { block_id: "events", content_en: "" },
        "3" => { block_id: "recipe", content_en: "" }
      })

    assert_difference -> { newsletter.deliveries.count }, 2 do
      perform_enqueued_jobs { newsletter.send! }
    end

    email = ActionMailer::Base.deliveries.first
    mail_body = email.parts.map(&:body).join
    assert_not_includes mail_body, "Here are the upcoming activities where we still need people:"
  end

  test "send default next delivery template (with basket content)" do
    travel_to "2024-04-04"
    org(features: [])
    Newsletter::Template.create_defaults!
    template = Newsletter::Template.find_by!(title: "Next delivery")
    newsletter = Newsletter.create!(
      template: template,
      audience: "delivery_id::#{deliveries(:thursday_1).gid}",
      subject: "Next delivery test",
      blocks_attributes: {
        "0" => { block_id: "intro", content_en: "Hello" },
        "2" => { block_id: "events", content_en: "" },
        "3" => { block_id: "recipe", content_en: "" }
      })

    create_basket_content(
      delivery: deliveries(:thursday_1),
      product: basket_content_products(:carrots),
      basket_size_ids_percentages: { large_id => 100 },
      quantity: 2,
      unit: "kg")
    create_basket_content(
      delivery: deliveries(:thursday_1),
      product: basket_content_products(:cucumbers),
      basket_size_ids_percentages: { large_id => 100 },
      quantity: 3,
      unit: "pc")
    create_basket_content(
      delivery: deliveries(:thursday_1),
      depots: [ depots(:farm) ],
      product: basket_content_products(:cucumbers),
      basket_size_ids_percentages: { large_id => 100 },
      quantity: 3,
      unit: "kg")

    assert_difference -> { newsletter.deliveries.count }, 1 do
      perform_enqueued_jobs { newsletter.send! }
    end

    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "jane@doe.com" ], mail.to
    mail_body = mail.parts.map(&:body).join
    assert_includes mail_body, "Large basket:</span>"
    assert_includes mail_body, ">Carrots (2.0kg)</li>"
    assert_includes mail_body, ">Cucumbers (3pc)</li>"
    assert_not_includes mail_body, ">Cucumbers (3.0kg)</li>"

    assert_includes mail_body, "Complement(s): Bread"
  end
end
