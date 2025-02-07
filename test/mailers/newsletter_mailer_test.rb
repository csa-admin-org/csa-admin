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
end
