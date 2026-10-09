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
    assert_includes mail_body, "/newsletters/unsubscribe/"
    assert_not_includes delivery.content, "/newsletters/unsubscribe/"
    assert_not_includes delivery.mail_preview, "/newsletters/unsubscribe/"
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

  test "sending a newsletter creates deliveries and emails before jobs run" do
    travel_to "2024-01-01"
    newsletter = create_active_newsletter

    assert_enqueued_jobs 2, only: MailDelivery::ProcessJob do
      newsletter.send!
    end

    deliveries = newsletter.mail_deliveries.order(:member_id)
    assert_equal 2, deliveries.size
    assert deliveries.all?(&:processing?)
    assert_equal %w[jane@doe.com john@doe.com],
      newsletter.mail_delivery_emails.processing.pluck(:email).sort
    assert_equal [ newsletter.id ], deliveries.first.mailable_ids
  end

  test "sending a newsletter keeps suppression and missing-email states" do
    travel_to "2024-01-01"
    members(:john).update!(emails: "john@doe.com, jojo@old.com")
    members(:jane).update!(emails: "")
    suppression = suppress_email("jojo@old.com", stream_id: "broadcast")
    newsletter = create_active_newsletter

    newsletter.send!

    john_delivery = newsletter.mail_deliveries.find_by!(member: members(:john))
    jane_delivery = newsletter.mail_deliveries.find_by!(member: members(:jane))
    assert_equal "processing", john_delivery.state
    assert_equal "not_delivered", jane_delivery.state
    assert_empty jane_delivery.emails

    emails = john_delivery.emails.order(:email)
    assert_equal %w[john@doe.com jojo@old.com], emails.map(&:email)
    assert emails.all?(&:processing?)
    suppressed = emails.find { |email| email.email == "jojo@old.com" }
    assert_equal [ suppression.id ], suppressed.email_suppression_ids
    assert_equal %w[HardBounce], suppressed.email_suppression_reasons
    assert_empty emails.find { |email| email.email == "john@doe.com" }.email_suppression_ids
  end

  test "sending a newsletter inserts recipient rows and enqueues process jobs in bulk" do
    travel_to "2024-01-01"
    3.times { |i| create_member(state: "active", emails: "bulk-#{i}@doe.com") }
    newsletter = create_active_newsletter
    expected_emails = newsletter.audience_segment.members.flat_map(&:active_emails)

    inserts = Hash.new(0)
    queries = []
    sql_callback = ->(_name, _start, _finish, _id, payload) {
      sql = payload[:sql].to_s
      next if payload[:name] == "SCHEMA" || sql.match?(/\A(?:BEGIN|COMMIT|SAVEPOINT|RELEASE)/i)

      queries << sql
      inserts[:mail_deliveries] += 1 if sql.match?(/INSERT INTO ["']mail_deliveries["']/i)
      inserts[:mail_delivery_emails] += 1 if sql.match?(/INSERT INTO ["']mail_delivery_emails["']/i)
    }

    assert_operator expected_emails.size, :>, 4
    assert_enqueued_jobs expected_emails.size, only: MailDelivery::ProcessJob do
      ActiveSupport::Notifications.subscribed(sql_callback, "sql.active_record") do
        newsletter.send!
      end
    end

    assert_equal 1, inserts[:mail_deliveries]
    assert_equal 1, inserts[:mail_delivery_emails]
    assert_operator queries.size, :<, 80
    assert_equal expected_emails.sort, newsletter.mail_delivery_emails.pluck(:email).sort
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

  test "deliveries_for uses the member newsletter list index" do
    columns = ActiveRecord::Base.connection.indexes(:mail_deliveries).map(&:columns)
    assert_includes columns, %w[member_id mailable_type created_at]

    sql = Newsletter.deliveries_for(members(:john)).limit(21).to_sql
    plan = ActiveRecord::Base.connection.exec_query("EXPLAIN QUERY PLAN #{sql}").rows.flatten.join(" ")
    assert_match(/idx_mail_deliveries_on_member_mailable_created/, plan)
  end

  test "deliveries_for is an unloaded relation of processed newsletter deliveries" do
    draft = MailDelivery.create!(
      mailable_type: "Newsletter",
      mailable_ids: [ newsletters(:sent).id ],
      action: "newsletter",
      member: members(:john),
      subject: "Draft",
      state: :draft)
    relation = Newsletter.deliveries_for(members(:john))

    assert_not relation.loaded?
    assert_includes relation, mail_deliveries(:sent_john)
    assert_not_includes relation, draft
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

  private

  def create_active_newsletter
    create_newsletter(
      audience: "member_state::active",
      template: newsletter_templates(:simple),
      blocks_attributes: {
        "0" => { block_id: "main", content_en: "Hello {{ member.name }}" }
      })
  end
end
