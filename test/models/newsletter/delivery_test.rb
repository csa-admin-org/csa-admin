# frozen_string_literal: true

require "test_helper"

class NewsletterDeliveryTest < ActiveSupport::TestCase
  test "store emails on creation" do
    newsletter = newsletters(:simple)

    members(:john).update!(emails: "john@bob.com, jojo@old.com")
    suppression = suppress_email("jojo@old.com", stream_id: "broadcast")

    assert_difference -> { MailDelivery::Email.count }, 2 do
      MailDelivery.deliver!(member: members(:john), mailable: newsletter, action: "newsletter")
      perform_enqueued_jobs
    end

    delivery = MailDelivery.last
    processing_email = delivery.emails.find_by(state: "processing")
    assert_equal members(:john), delivery.member
    assert_equal "john@bob.com", processing_email.email
    assert_empty processing_email.email_suppression_ids

    suppressed_email = delivery.emails.find_by(state: "suppressed")
    assert_equal "jojo@old.com", suppressed_email.email
    assert_equal [ suppression.id ], suppressed_email.email_suppression_ids
    assert_equal %w[ HardBounce ], suppressed_email.email_suppression_reasons
  end

  test "store delivery even for members without email" do
    members(:john).update!(emails: "")
    newsletter = newsletters(:simple)

    assert_difference -> { MailDelivery.count }, 1 do
      assert_no_difference -> { MailDelivery::Email.count } do
        MailDelivery.deliver!(member: members(:john), mailable: newsletter, action: "newsletter")
      end
    end

    delivery = MailDelivery.last
    assert_equal members(:john), delivery.member
    assert_equal "not_delivered", delivery.state
    assert_empty delivery.emails
  end

  test "send newsletter" do
    newsletter = newsletters(:simple)

    assert_difference -> { ActionMailer::Base.deliveries.count }, 2 do
      perform_enqueued_jobs do
        newsletter.send!
      end
    end

    delivery = MailDelivery.for_mailable(newsletter).order(:id).last
    assert_equal "Subject Jane Doe", delivery.subject
    assert_includes delivery.content, "Hello Jane Doe,"
    assert_includes delivery.content, "Block Jane Doe"

    assert_equal [ %w[ john@doe.com ], %w[ jane@doe.com ] ], ActionMailer::Base.deliveries.map(&:to)

    email = ActionMailer::Base.deliveries.last
    assert_equal [ "info@acme.test" ], email.from
    assert_equal "Subject Jane Doe", email.subject
    mail_body = email.parts.map(&:body).join
    assert_includes mail_body, "Hello Jane Doe,"
    assert_includes mail_body, "Block Jane Doe"
    assert_includes mail_body, "Best regards,\n", "<br>Acme</p>"
  end

  test "send newsletter with custom from" do
    newsletter = newsletters(:simple)
    newsletter.update!(from: "contact@acme.test")

    assert_difference -> { ActionMailer::Base.deliveries.count }, 2 do
      perform_enqueued_jobs do
        newsletter.send!
      end
    end

    email = ActionMailer::Base.deliveries.first
    assert_equal [ "contact@acme.test" ], email.from
  end

  test "send newsletter with custom signature" do
    newsletter = newsletters(:simple)
    newsletter.update!(signature: "XoXo")

    assert_difference -> { ActionMailer::Base.deliveries.count }, 2 do
      perform_enqueued_jobs do
        newsletter.send!
      end
    end

    email = ActionMailer::Base.deliveries.first
    mail_body = email.parts.map(&:body).join
    assert_not_includes mail_body, "Best regards,"
    assert_includes mail_body, "XoXo"
  end

  test "send newsletter with attachments" do
    attachment = Attachment.new
    attachment.file.attach(io: File.open(file_fixture("qrcode-test.png")), filename: "qrcode-test.png")

    newsletter = newsletters(:simple)
    newsletter.update!(attachments: [ attachment ])

    assert_difference -> { ActionMailer::Base.deliveries.count }, 2 do
      perform_enqueued_jobs do
        newsletter.send!
      end
    end

    mail = ActionMailer::Base.deliveries.first
    assert_equal "broadcast", mail[:message_stream].to_s

    assert_equal 1, mail.attachments.size
    attachment = mail.attachments.first
    assert_equal "qrcode-test.png", attachment.filename
    assert_equal "image/png", attachment.content_type
  end

  test "persist deliveries draft when saved" do
    travel_to "2024-01-01"
    members(:john).update!(emails: "john@doe.com, jojo@old.com")
    suppress_email("jojo@old.com", stream_id: "broadcast")

    newsletter = build_newsletter(
      audience: "member_state::active",
      template: newsletter_templates(:simple),
      blocks_attributes: {
        "0" => { block_id: "main", content_en: "Hello {{ member.name }}" }
      })

    assert_difference -> { MailDelivery.count }, 2 do
      assert_no_difference -> { MailDelivery::Email.count } do
        newsletter.save!
      end
    end

    assert_equal 2, newsletter.mail_deliveries.draft.count
    assert_empty newsletter.mail_delivery_emails
  end

  test "destroy newsletter cleans up mail deliveries and emails" do
    travel_to "2024-01-01"
    newsletter = build_newsletter(
      audience: "member_state::active",
      template: newsletter_templates(:simple),
      blocks_attributes: {
        "0" => { block_id: "main", content_en: "Hello {{ member.name }}" }
      })
    newsletter.save!
    perform_enqueued_jobs { newsletter.send! }

    assert newsletter.mail_deliveries.any?
    assert newsletter.mail_delivery_emails.any?

    assert_difference -> { MailDelivery.count }, -newsletter.mail_deliveries.count do
      assert_difference -> { MailDelivery::Email.count }, -newsletter.mail_delivery_emails.count do
        newsletter.destroy!
      end
    end
  end

  test "deliveries_with_missing_emails" do
    travel_to "2024-01-01"
    newsletter = build_newsletter(
      audience: "member_state::active",
      template: newsletter_templates(:simple),
      blocks_attributes: {
        "0" => { block_id: "main", content_en: "Hello {{ member.name }}" }
      })
    newsletter.save!
    perform_enqueued_jobs { newsletter.send! }

    members(:john).update!(emails: "john@new.com")

    deliveries = newsletter.reload.deliveries_with_missing_emails
    assert_equal 1, deliveries.size

    delivery = deliveries.first
    assert_equal members(:john), delivery.member
    assert_equal %w[john@new.com], delivery.missing_emails

    processing_count = -> {
      newsletter.reload.mail_delivery_emails.processing.count
    }

    assert_difference -> { processing_count.call }, 1 do
      assert_difference -> { ActionMailer::Base.deliveries.count }, 1 do
        perform_enqueued_jobs { delivery.deliver_missing_email!("john@new.com") }
      end
    end

    mail = ActionMailer::Base.deliveries.last
    assert_equal %w[john@new.com], mail.to
    assert_includes mail.html_part.body.to_s, "Hello John Doe"

    assert_empty newsletter.reload.deliveries_with_missing_emails
  end
end
