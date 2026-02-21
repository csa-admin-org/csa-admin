# frozen_string_literal: true

require "test_helper"

class EmailSuppressionTest < ActiveSupport::TestCase
  setup { postmark_client.reset! }

  def suppress!(stream_id, email, reason, origin)
    EmailSuppression.create!(
      stream_id: stream_id,
      email: email,
      reason: reason,
      origin: origin)
  end

  test "sync_postmark!" do
    freeze_time
    suppress!("outbound", "a@b.com", "HardBounce", "Recipient").unsuppress!
    postmark_client.dump_suppressions_response = [
      {
        email_address: "a@b.com",
        suppression_reason: "HardBounce",
        origin: "Recipient",
        created_at: Time.current.to_s
      }, {
        email_address: "D@f.com",
        suppression_reason: "SpamComplaint",
        origin: "Customer",
        created_at: 1.hour.ago
      }
    ]

    assert_difference -> { EmailSuppression.outbound.count } do
      EmailSuppression.sync_postmark!
    end
    assert_equal "d@f.com", EmailSuppression.outbound.active.first.email
    assert_equal "SpamComplaint", EmailSuppression.outbound.active.first.reason
    assert_equal "Customer", EmailSuppression.outbound.active.first.origin
    assert_equal 1.hour.ago, EmailSuppression.outbound.active.first.created_at
  end

  test "unsuppress! unsuppresses all suppressable suppression with given email" do
    suppress!("outbound", "a@b.com", "HardBounce", "Recipient")
    suppress!("outbound", "d@f.com", "HardBounce", "Recipient")
    suppress!("outbound", "z@y.com", "ManualSuppression", "Customer")
    suppress!("broadcast", "a@b.com", "HardBounce", "Recipient")

    assert_difference -> { EmailSuppression.active.count }, -1 do
      EmailSuppression.unsuppress!("A@b.com", stream_id: "outbound", origin: "Recipient")
    end
    assert_empty EmailSuppression.active.outbound.where(email: "a@b.com")
    assert_equal [ [ :delete_suppressions, "outbound", "a@b.com" ] ], postmark_client.calls
  end

  test "unsuppress! skips undeletable emails" do
    suppress!("outbound", "z@y.com", "ManualSuppression", "Customer")

    assert_no_difference -> { EmailSuppression.active.count } do
      EmailSuppression.unsuppress!("z@y.com", stream_id: "outbound", origin: "Recipient")
    end
    assert_empty postmark_client.calls
  end

  test "suppress! creates new suppression" do
    suppress!("outbound", "A@b.com", "HardBounce", "Recipient")
    suppress!("broadcast", "a@b.com", "HardBounce", "Recipient")

    assert_difference -> { EmailSuppression.active.count }, 1 do
      EmailSuppression.suppress!("x@y.com", stream_id: "outbound", origin: "Customer", reason: "ManualSuppression")
    end
    assert_equal "x@y.com", EmailSuppression.active.find_by(email: "x@y.com").email
    assert_equal "outbound", EmailSuppression.active.find_by(email: "x@y.com").stream_id
    assert_equal "Customer", EmailSuppression.active.find_by(email: "x@y.com").origin
    assert_equal "ManualSuppression", EmailSuppression.active.find_by(email: "x@y.com").reason
    assert_equal [ [ :create_suppressions, "outbound", "x@y.com" ] ], postmark_client.calls
  end

  test "suppress! skips already suppressed email" do
    suppress!("outbound", "A@b.com", "HardBounce", "Recipient")

    assert_no_difference -> { EmailSuppression.active.count } do
      EmailSuppression.suppress!("a@B.com", stream_id: "outbound", origin: "Customer", reason: "ManualSuppression")
    end
    assert_empty postmark_client.calls
  end

  test "notifies admins when created" do
    admin = admins(:ultra)
    admin.update!(notifications: [ "new_email_suppression" ])
    suppress!("outbound", "A@b.com", "HardBounce", "Recipient")

    perform_enqueued_jobs

    assert_equal 1, AdminMailer.deliveries.size
    mail = AdminMailer.deliveries.last
    assert_equal "Email rejected (HardBounce)", mail.subject
    assert_equal [ admin.email ], mail.to
    assert_includes mail.html_part.body.to_s, admin.name
  end

  test "unsuppress! retries recent suppressed email deliveries" do
    member = members(:john)
    member.update!(emails: "jojo@old.com")
    suppression = suppress_email("jojo@old.com", stream_id: "broadcast")

    perform_enqueued_jobs do
      MailDelivery.deliver!(member: member, mailable: newsletters(:simple), action: "newsletter")
    end

    email = MailDelivery::Email.last
    assert email.suppressed?
    assert_equal "not_delivered", email.mail_delivery.reload.state

    assert_enqueued_with(job: MailDelivery::ProcessJob) do
      suppression.unsuppress!
    end

    email.reload
    assert email.processing?
    assert_empty email.email_suppression_ids
    assert_empty email.email_suppression_reasons
    assert_equal "processing", email.mail_delivery.reload.state
  end

  test "unsuppress! does not retry old suppressed email deliveries" do
    member = members(:john)
    member.update!(emails: "jojo@old.com")
    suppression = suppress_email("jojo@old.com", stream_id: "broadcast")

    perform_enqueued_jobs do
      MailDelivery.deliver!(member: member, mailable: newsletters(:simple), action: "newsletter")
    end

    email = MailDelivery::Email.last
    assert email.suppressed?

    travel MailDelivery::MISSING_EMAILS_ALLOWED_PERIOD + 1.day do
      suppression.unsuppress!
    end

    email.reload
    assert email.suppressed?, "old delivery should not be retried"
  end

  test "does not notify manual suppression to admins when created" do
    admin = admins(:ultra)
    admin.update!(notifications: [ "new_email_suppression" ])
    suppress!("outbound", "a@B.com", "ManualSuppression", "Customer")

    assert_equal 0, AdminMailer.deliveries.size
  end
end
