# frozen_string_literal: true

require "test_helper"

class NewsletterMailerTest < ActionMailer::TestCase
  test "newsletter_email" do
    template = newsletter_templates(:simple)
    member = members(:john)

    mail = NewsletterMailer.with(
      tag: "newsletter-42",
      template: template,
      template_contents: template.contents, # Avoid preview data usage
      subject: "My Newsletter",
      member: member,
      to: "john@doe.com"
    ).newsletter_email

    assert_equal "My Newsletter", mail.subject
    assert_equal [ "john@doe.com" ], mail.to
    assert_equal "Acme <info@acme.test>", mail[:from].decoded
    assert_equal "broadcast", mail[:message_stream].to_s
    assert_equal "newsletter-42", mail[:tag].to_s

    body = mail.body.to_s
    assert_includes body, "Hello John Doe,"
    assert_includes body, '<h2 class="content_title">Content Title</h2>'
    assert_includes body, "Example Text John Doe"
    assert_match %r{https://members.acme.test/newsletters/unsubscribe/\w{32}}, body
    assert_equal "List-Unsubscribe=One-Click", mail["List-Unsubscribe-Post"].to_s
    assert_match %r{<https://members.acme.test/newsletters/unsubscribe/\w{32}/post>},
      mail["List-Unsubscribe"].to_s
  end

  test "newsletter_email with attachments" do
    newsletter = newsletters(:simple)
    member = members(:john)

    attachment = Attachment.new
    attachment.file.attach(
      io: File.open(file_fixture("qrcode-test.png")),
      filename: 'A "stylish" QR code.png')
    newsletter.update!(attachments: [ attachment ])

    mail = NewsletterMailer.with(
      template: newsletter.template,
      subject: "My Newsletter",
      member: member,
      attachments: [ attachment ],
      to: "john@doe.com"
    ).newsletter_email

    assert_equal 1, mail.attachments.size
    attachment = mail.attachments.first
    assert_equal "A -stylish- QR code.png", attachment.filename
    assert_equal "image/png", attachment.content_type
  end

  test "prepared_data includes basket for member with deliverable basket" do
    travel_to "2024-04-01" do
      mail = NewsletterMailer.with(
        template_contents: { "en" => "basket:{{ basket.description }}" },
        subject: "Test",
        member: members(:john),
        to: "john@doe.com"
      ).newsletter_email

      assert_includes mail.body.to_s, "basket:Medium basket"
    end
  end

  test "prepared_data includes basket for member on different delivery cycle" do
    travel_to "2024-04-01" do
      mail = NewsletterMailer.with(
        template_contents: { "en" => "basket:{{ basket.description }}" },
        subject: "Test",
        member: members(:jane),
        to: "jane@doe.com"
      ).newsletter_email

      assert_includes mail.body.to_s, "basket:Large basket"
    end
  end

  test "prepared_data excludes basket when member is absent" do
    travel_to "2024-04-29" do
      mail = NewsletterMailer.with(
        template_contents: { "en" => "basket:{{ basket.description }},membership:{{ membership.start_date }}" },
        subject: "Test",
        member: members(:jane),
        to: "jane@doe.com"
      ).newsletter_email

      assert_includes mail.body.to_s, "basket:,membership:1 January 2024"
    end
  end

  test "prepared_data provides membership when no basket in window" do
    travel_to "2024-04-04" do
      mail = NewsletterMailer.with(
        template_contents: { "en" => "basket:{{ basket.description }},membership:{{ membership.start_date }}" },
        subject: "Test",
        member: members(:john),
        to: "john@doe.com"
      ).newsletter_email

      assert_includes mail.body.to_s, "basket:,membership:1 January 2024"
    end
  end
end
