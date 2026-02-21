# frozen_string_literal: true

require "test_helper"

class MailDelivery::Email::RetriableTest < ActiveSupport::TestCase
  test "retry! transitions suppressed email back to processing" do
    member = members(:john)
    member.update!(emails: "jojo@old.com")
    suppression = suppress_email("jojo@old.com", stream_id: "broadcast")

    perform_enqueued_jobs do
      MailDelivery.deliver!(member: member, mailable: newsletters(:simple), action: "newsletter")
    end

    email = MailDelivery::Email.last
    assert email.suppressed?
    assert_equal "not_delivered", email.mail_delivery.reload.state

    suppression.unsuppress!

    assert_enqueued_with(job: MailDelivery::ProcessJob) do
      email.retry!
    end

    email.reload
    assert email.processing?
    assert_empty email.email_suppression_ids
    assert_empty email.email_suppression_reasons
    assert_equal "processing", email.mail_delivery.reload.state
  end

  test "retry! stays suppressed when other active suppressions remain" do
    member = members(:john)
    member.update!(emails: "jojo@old.com")
    suppression1 = suppress_email("jojo@old.com", stream_id: "broadcast")
    # Create a second broadcast suppression with a different reason
    suppression2 = EmailSuppression.create!(
      email: "jojo@old.com",
      stream_id: "broadcast",
      reason: "ManualSuppression",
      origin: "Admin")

    perform_enqueued_jobs do
      MailDelivery.deliver!(member: member, mailable: newsletters(:simple), action: "newsletter")
    end

    email = MailDelivery::Email.last
    assert email.suppressed?

    # Unsuppress only the HardBounce one
    suppression1.unsuppress!

    email.reload
    assert email.suppressed?
    assert_equal [ suppression2.id ], email.email_suppression_ids
    assert_equal %w[ManualSuppression], email.email_suppression_reasons
  end

  test "retry! raises for non-suppressed email" do
    member = members(:john)
    delivery = MailDelivery.deliver!(
      member: member, mailable: invoices(:annual_fee), action: "created")

    email = delivery.emails.first
    assert email.processing?

    assert_raises(InvalidTransitionError) do
      email.retry!
    end
  end

  test "retriable_for scope finds suppressed emails within allowed period" do
    member = members(:john)
    member.update!(emails: "jojo@old.com")
    suppression = suppress_email("jojo@old.com", stream_id: "broadcast")

    perform_enqueued_jobs do
      MailDelivery.deliver!(member: member, mailable: newsletters(:simple), action: "newsletter")
    end

    email = MailDelivery::Email.last
    assert email.suppressed?

    assert_includes MailDelivery::Email.retriable_for(suppression), email
  end

  test "retriable_for scope excludes emails older than allowed period" do
    member = members(:john)
    member.update!(emails: "jojo@old.com")
    suppression = suppress_email("jojo@old.com", stream_id: "broadcast")

    perform_enqueued_jobs do
      MailDelivery.deliver!(member: member, mailable: newsletters(:simple), action: "newsletter")
    end

    email = MailDelivery::Email.last
    assert email.suppressed?

    travel MailDelivery::MISSING_EMAILS_ALLOWED_PERIOD + 1.day do
      assert_not_includes MailDelivery::Email.retriable_for(suppression), email
    end
  end

  test "retriable_for scope excludes emails not linked to given suppression" do
    member = members(:john)
    member.update!(emails: "jojo@old.com")
    suppress_email("jojo@old.com", stream_id: "broadcast")
    other_suppression = suppress_email("other@test.com", stream_id: "broadcast")

    perform_enqueued_jobs do
      MailDelivery.deliver!(member: member, mailable: newsletters(:simple), action: "newsletter")
    end

    email = MailDelivery::Email.last
    assert email.suppressed?

    assert_not_includes MailDelivery::Email.retriable_for(other_suppression), email
  end
end
