# frozen_string_literal: true

require "test_helper"

class NewsletterTest < ActiveSupport::TestCase
  test "validate from hostname" do
    assert_equal "acme.test", Current.org.domain

    newsletter = build_newsletter(from: "contact@acme.test")
    assert newsletter.valid?

    newsletter = build_newsletter(from: nil)
    assert newsletter.valid?

    newsletter = build_newsletter(from: "")
    assert newsletter.valid?

    newsletter = build_newsletter(from: "info@orga.ch")
    assert_not newsletter.valid?
    assert_includes newsletter.errors[:from], "is invalid"
  end

  test "validate scheduled_at date" do
    newsletter = build_newsletter(scheduled_at: Date.current)
    assert_not newsletter.valid?

    newsletter = build_newsletter(scheduled_at: Date.tomorrow)
    assert newsletter.valid?
  end

  test "validate subject liquid" do
    newsletter = build_newsletter(subject: "Foo {{ ")
    assert_not newsletter.valid?
    assert_includes newsletter.errors[:subject_en],
      "Liquid syntax error: Variable '{{' was not properly terminated with regexp: /\\}\\}/"
  end

  test "validate subject html" do
    newsletter = build_newsletter(subject: "Foo <i>bar")
    assert_not newsletter.valid?
    assert_includes newsletter.errors[:subject_en],
      "HTML error at line 1: Generic parser"
  end

  test "validate at least content must be present" do
    newsletter = build_newsletter(blocks_attributes: {
      "0" => { block_id: "first", content_en: "" },
      "1" => { block_id: "second", content_en: "" }
    })
    assert_not newsletter.valid?
    assert_includes newsletter.errors[:blocks], "can't be empty"
  end

  test "validate block content liquid" do
    newsletter = build_newsletter(blocks_attributes: {
      "0" => { block_id: "first", content_en: "Foo {{" }
    })
    assert_not newsletter.relevant_blocks.first.valid?
    assert_includes newsletter.relevant_blocks.first.errors[:content_en],
      "Liquid syntax error: Variable '{{' was not properly terminated with regexp: /\\}\\}/"
  end

  test "validate html body size" do
    newsletter = build_newsletter(blocks_attributes: {
      "0" => { block_id: "first", content_en: "Hello" }
    })
    assert newsletter.valid?

    # Test the validation method directly with a mock
    max_size = Newsletter::MAXIMUM_HTML_BODY_SIZE
    newsletter.define_singleton_method(:mail_preview) { |_locale| "x" * (max_size + 1) }

    assert_not newsletter.valid?
    assert_includes newsletter.errors[:base], "Newsletter has too much content"
  end

  test "schedulable scope" do
    travel_to "2025-04-01"
    create_newsletter
    n1 = create_newsletter(scheduled_at: "2025-04-02")
    create_newsletter(scheduled_at: "2025-04-02").send!
    n2 = create_newsletter(scheduled_at: "2025-04-03")
    create_newsletter(scheduled_at: "2025-04-04")

    travel_to "2025-04-03"
    assert_equal [ n1.id, n2.id ], Newsletter.schedulable.pluck(:id)
  end

  test "mailpreview" do
    newsletter = build_newsletter(
      subject: "My Super Newsletter",
      blocks_attributes: {
        "0" => { block_id: "first", content_en: "Hello {{ member.name }}" },
        "1" => { block_id: "second", content_en: "Youpla Boom" }
      })
    newsletter.liquid_data_preview_yamls = {
      "en" => <<~YAML
        member:
          name: Bob Doe
        subject: Ma Newsletter
      YAML
    }

    mail = newsletter.mail_preview("en")
    assert_includes mail, "My Super Newsletter</h1>"
    assert_includes mail, "First EN</h2>"
    assert_includes mail, "Hello Bob Doe"
    assert_includes mail, "Youpla Boom"
    assert_includes mail, "Best regards,"
    assert_includes mail, "Acme"
  end

  test "mailpreview with custom signature" do
    newsletter = build_newsletter(signature: "XoXo")

    mail = newsletter.mail_preview("en")
    assert_not_includes mail, "Best regards,"
    assert_includes mail, "XoXo"
  end

  test "mailpreview is using persisted template content and preview data once sent" do
    newsletter = build_newsletter(
      subject: "My Super Newsletter",
      blocks_attributes: {
        "0" => { block_id: "first", content_en: "Hello {{ member.name }}" },
        "1" => { block_id: "second", content_en: "Youpla Boom" }
      })
    preview_yamls = {
      "en" => <<~YAML
        member:
          name: Bob Doe
        subject: My Newsletter
      YAML
    }
    newsletter.liquid_data_preview_yamls = preview_yamls

    mail = newsletter.mail_preview("en")
    assert_includes mail, "My Super Newsletter</h1>"
    assert_includes mail, "First EN</h2>"
    assert_includes mail, "Hello Bob Doe"
    assert_includes mail, "Youpla Boom"

    newsletter.send!

    newsletter_templates(:dual).update!(content_en: <<~LIQUID)
      {% content id: 'first', title: 'First NEW EN' %}
        FIRST CONTENT EN
      {% endcontent %}
      NEW LINE
      {% content id: 'second' %}
        SECOND CONTENT EN
      {% endcontent %}
    LIQUID

    newsletter = Newsletter.find(newsletter.id) # hard reload

    assert_equal preview_yamls, newsletter[:liquid_data_preview_yamls]

    mail = newsletter.mail_preview("en")
    assert_includes mail, "My Super Newsletter</h1>"
    assert_includes mail, "First EN</h2>"
    assert_not_includes mail, "NEW LINE"
    assert_includes mail, "Hello Bob Doe"
    assert_includes mail, "Youpla Boom"
  end

  test "persist deliveries draft when saved" do
    members(:john).update!(emails: "john@doe.com, jojo@old.com")
    suppress_email("jojo@old.com", stream_id: "broadcast")

    newsletter = build_newsletter(
      audience: "member_state::active",
      template: newsletter_templates(:simple),
      blocks_attributes: {
        "0" => { block_id: "main", content_en: "Hello {{ member.name }}" }
      })

    assert_difference -> { newsletter.deliveries.count }, 3 do
      newsletter.save!
    end

    assert_equal "jojo@old.com", newsletter.deliveries.ignored.first.email
    assert_equal %w[john@doe.com jane@doe.com], newsletter.deliveries.draft.pluck(:email)
    assert_empty newsletter.deliveries.processed
  end

  test "send newsletter" do
    newsletter = build_newsletter(
      audience: "member_state::active",
      template: newsletter_templates(:simple),
      blocks_attributes: {
        "0" => { block_id: "main", content_en: "Hello {{ member.name }}" }
      })
    newsletter.save!

    members(:john).update!(emails: "john@doe.com, jojo@old.com")
    suppression = suppress_email("jojo@old.com", stream_id: "broadcast")

    assert_equal 2, newsletter.audience_segment.members.count
    assert_equal %w[john@doe.com jane@doe.com], newsletter.audience_segment.emails
    assert_equal %w[jojo@old.com], newsletter.audience_segment.suppressed_emails

    assert_empty newsletter[:template_contents]
    assert_empty newsletter[:liquid_data_preview_yamls]

    assert_difference -> { newsletter.reload.deliveries.processing.count }, 2 do
      assert_difference -> { ActionMailer::Base.deliveries.count }, 2 do
        perform_enqueued_jobs { newsletter.send! }
      end
    end

    assert_equal 1, newsletter.deliveries.ignored.count
    assert_equal "jojo@old.com", newsletter.deliveries.ignored.first.email
    assert_equal [ suppression.id ], newsletter.deliveries.ignored.first.email_suppression_ids
    assert_equal [ "HardBounce" ], newsletter.deliveries.ignored.first.email_suppression_reasons

    newsletter = Newsletter.find(newsletter.id) # hard reload
    assert newsletter.sent?
    assert_equal 2, newsletter.members.count
    assert_equal %w[john@doe.com jane@doe.com], newsletter.deliveries.processing.pluck(:email)
    assert_equal %w[jojo@old.com], newsletter.deliveries.ignored.pluck(:email)
    assert_equal newsletter.template.contents, newsletter.template_contents
    assert_not newsletter[:liquid_data_preview_yamls].empty?
    assert_equal({ "en" => "Members: Active" }, newsletter.audience_names)
  end

  test "send single email" do
    newsletter = build_newsletter(
      audience: "member_state::active",
      template: newsletter_templates(:simple),
      blocks_attributes: {
        "0" => { block_id: "main", content_en: "Hello {{ member.name }}" }
      })
    newsletter.save!
    perform_enqueued_jobs { newsletter.send! }

    members(:john).update!(emails: "john@new.com")

    assert_equal %w[john@new.com], newsletter.reload.missing_delivery_emails

    assert_difference -> { newsletter.reload.deliveries.processing.count }, 1 do
      assert_difference -> { ActionMailer::Base.deliveries.count }, 1 do
        perform_enqueued_jobs { newsletter.deliver!("john@new.com") }
      end
    end

    mail = ActionMailer::Base.deliveries.last
    assert_equal %w[john@new.com], mail.to
    assert_includes mail.html_part.body.to_s, "Hello John Doe"
  end
end
