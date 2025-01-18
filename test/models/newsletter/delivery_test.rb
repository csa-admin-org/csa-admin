# frozen_string_literal: true

require "test_helper"

class NewsletterDeliveryTest < ActiveSupport::TestCase
  test "store emails on creation" do
    newsletter = newsletters(:simple)

    members(:john).update!(emails: "john@bob.com, jojo@old.com")
    suppression = suppress_email("jojo@old.com", stream_id: "broadcast")

    assert_difference -> { Newsletter::Delivery.count }, 2 do
      Newsletter::Delivery.create_for!(newsletter, members(:john))
      perform_enqueued_jobs
    end

    processing = Newsletter::Delivery.processing.last
    assert_equal members(:john), processing.member
    assert_equal "john@bob.com", processing.email
    assert_equal [], processing.email_suppression_ids

    ignored = Newsletter::Delivery.ignored.last
    assert_equal members(:john), ignored.member
    assert_equal "jojo@old.com", ignored.email
    assert_equal [ suppression.id ], ignored.email_suppression_ids
    assert_equal %w[ HardBounce ], ignored.email_suppression_reasons
  end

  test "store delivery even for members without email" do
    members(:john).update!(emails: "")
    newsletter = newsletters(:simple)

    assert_difference -> { Newsletter::Delivery.count } do
      perform_enqueued_jobs do
        Newsletter::Delivery.create_for!(newsletter, members(:john))
      end
    end

    delivery = Newsletter::Delivery.last
    assert_equal members(:john), delivery.member
    assert_nil delivery.email
    assert_equal [], delivery.email_suppression_ids
  end

  test "send newsletter" do
    newsletter = newsletters(:simple)
    # simulate newsletter sent
    newsletter.update!(template_contents: newsletter_templates(:simple).contents)

    assert_difference -> { ActionMailer::Base.deliveries.count } do
      perform_enqueued_jobs do
        Newsletter::Delivery.create_for!(newsletter, members(:jane))
      end
    end

    delivery = Newsletter::Delivery.last
    assert_equal "Subject Jane Doe", delivery.subject
    assert_includes delivery.content, "Hello Jane Doe,"
    assert_includes delivery.content, "Block Jane Doe"

    assert_equal [ %w[ jane@doe.com ] ], ActionMailer::Base.deliveries.map(&:to)

    email = ActionMailer::Base.deliveries.first
    assert_equal [ "info@acme.test" ], email.from
    assert_equal "Subject Jane Doe", email.subject
    mail_body = email.parts.map(&:body).join
    assert_includes mail_body, "Hello Jane Doe,"
    assert_includes mail_body, "Block Jane Doe"
    assert_includes mail_body, "Best regards,\n<br />Acme</p>"
  end

  test "send newsletter with custom from" do
    newsletter = newsletters(:simple)
    newsletter.update!(
      from: "contact@acme.test",
      # simulate newsletter sent
      template_contents: newsletter_templates(:simple).contents)

    assert_difference -> { ActionMailer::Base.deliveries.count } do
      perform_enqueued_jobs do
        Newsletter::Delivery.create_for!(newsletter, members(:jane))
      end
    end

    email = ActionMailer::Base.deliveries.first
    assert_equal [ "contact@acme.test" ], email.from
  end

  test "send newsletter with custom signature" do
    newsletter = newsletters(:simple)
    newsletter.update!(
      signature: "XoXo",
      # simulate newsletter sent
      template_contents: newsletter_templates(:simple).contents)

    assert_difference -> { ActionMailer::Base.deliveries.count } do
      perform_enqueued_jobs do
        Newsletter::Delivery.create_for!(newsletter, members(:jane))
      end
    end

    email = ActionMailer::Base.deliveries.first
    mail_body = email.parts.map(&:body).join
    assert_not_includes mail_body, "Best regards,"
    assert_includes mail_body, "XoXo"
  end

  test "send newsletter with attachments" do
    attachment = Newsletter::Attachment.new
    attachment.file.attach(io: File.open(file_fixture("qrcode-test.png")), filename: "qrcode-test.png")

    newsletter = newsletters(:simple)
    newsletter.update!(
      attachments: [ attachment ],
      # simulate newsletter sent
      template_contents: newsletter.template.contents)

    assert_difference -> { ActionMailer::Base.deliveries.count }, 1 do
      perform_enqueued_jobs do
        Newsletter::Delivery.create_for!(newsletter, members(:jane))
      end
    end

    mail = ActionMailer::Base.deliveries.first
    assert_equal "broadcast", mail[:message_stream].to_s

    assert_equal 1, mail.attachments.size
    attachment = mail.attachments.first
    assert_equal "qrcode-test.png", attachment.filename
    assert_equal "image/png", attachment.content_type
  end
end
