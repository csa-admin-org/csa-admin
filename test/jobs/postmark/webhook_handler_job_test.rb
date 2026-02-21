# frozen_string_literal: true

require "test_helper"

class Postmark::WebhookHandlerJobTest < ActiveJob::TestCase
  # --- Lookup: MailDelivery::Email by postmark_message_id ---

  test "delivery webhook matched by postmark_message_id transitions to delivered" do
    member = members(:john)
    delivery = MailDelivery.deliver!(
      member: member, mailable: invoices(:annual_fee), action: "created")
    email_record = delivery.emails.first
    email_record.update_column(:postmark_message_id, "pm-msg-001")

    payload = {
      record_type: "Delivery",
      message_stream: "outbound",
      message_id: "pm-msg-001",
      recipient: "john@doe.com",
      delivered_at: "2024-06-10T10:00:00Z",
      details: "Delivered OK",
      tag: "invoice-created"
    }

    perform_enqueued_jobs do
      Postmark::WebhookHandlerJob.perform_later(**payload)
    end

    email_record.reload
    assert email_record.delivered?
    assert_equal Time.parse("2024-06-10T10:00:00Z"), email_record.delivered_at
    assert_equal "pm-msg-001", email_record.postmark_message_id
    assert_equal "Delivered OK", email_record.postmark_details
  end

  test "bounce webhook matched by postmark_message_id transitions to bounced" do
    member = members(:john)
    delivery = MailDelivery.deliver!(
      member: member, mailable: member, mailable_type: "Member", action: "validated")
    email_record = delivery.emails.first
    email_record.update_column(:postmark_message_id, "pm-msg-002")

    payload = {
      record_type: "Bounce",
      message_stream: "outbound",
      message_id: "pm-msg-002",
      email: "john@doe.com",
      bounced_at: "2024-06-10T10:05:00Z",
      details: "Bounce details",
      tag: "member-validated",
      type: "HardBounce",
      type_code: 1,
      description: "Unknown user"
    }

    perform_enqueued_jobs do
      Postmark::WebhookHandlerJob.perform_later(**payload)
    end

    email_record.reload
    assert email_record.bounced?
    assert_equal Time.parse("2024-06-10T10:05:00Z"), email_record.bounced_at
    assert_equal "pm-msg-002", email_record.postmark_message_id
    assert_equal "Bounce details", email_record.postmark_details
    assert_equal "HardBounce", email_record.bounce_type
    assert_equal 1, email_record.bounce_type_code
    assert_equal "Unknown user", email_record.bounce_description
  end

  # --- Idempotency: duplicate webhooks are no-ops ---

  test "duplicate delivery webhook is a no-op for already delivered MailDelivery::Email" do
    member = members(:john)
    delivery = MailDelivery.deliver!(
      member: member, mailable: invoices(:annual_fee), action: "created")
    email_record = delivery.emails.first
    email_record.update_column(:postmark_message_id, "pm-idempotent-001")
    email_record.delivered!(at: Time.parse("2024-06-10T10:00:00Z"))

    assert email_record.delivered?

    payload = {
      record_type: "Delivery",
      message_stream: "outbound",
      message_id: "pm-idempotent-001",
      recipient: "john@doe.com",
      delivered_at: "2024-06-10T10:00:00Z",
      details: "Duplicate delivery",
      tag: "invoice-created"
    }

    # Should not raise, should be a no-op
    assert_nothing_raised do
      perform_enqueued_jobs do
        Postmark::WebhookHandlerJob.perform_later(**payload)
      end
    end

    email_record.reload
    assert email_record.delivered?
    # postmark_details should NOT be overwritten by the duplicate
    assert_nil email_record.postmark_details
  end

  test "duplicate bounce webhook is a no-op for already bounced MailDelivery::Email" do
    member = members(:john)
    delivery = MailDelivery.deliver!(
      member: member, mailable: invoices(:annual_fee), action: "created")
    email_record = delivery.emails.first
    email_record.update_column(:postmark_message_id, "pm-idempotent-002")
    email_record.bounced!(at: Time.parse("2024-06-10T10:00:00Z"), bounce_type: "HardBounce")

    assert email_record.bounced?

    payload = {
      record_type: "Bounce",
      message_stream: "outbound",
      message_id: "pm-idempotent-002",
      email: "john@doe.com",
      bounced_at: "2024-06-10T11:00:00Z",
      details: "Duplicate bounce",
      tag: "invoice-created",
      type: "SoftBounce",
      type_code: 4002,
      description: "Retry"
    }

    assert_nothing_raised do
      perform_enqueued_jobs do
        Postmark::WebhookHandlerJob.perform_later(**payload)
      end
    end

    email_record.reload
    assert email_record.bounced?
    assert_equal "HardBounce", email_record.bounce_type
  end

  test "duplicate delivery webhook is a no-op for already delivered newsletter email" do
    newsletter = newsletters(:simple)
    member = members(:john)
    mail_delivery = MailDelivery.create!(
      mailable_type: "Newsletter", mailable_ids: [ newsletter.id ], action: "newsletter",
      member: member, state: :processing)
    email_record = mail_delivery.emails.create!(
      email: "john@doe.com", state: :processing,
      postmark_message_id: "pm-nl-dup-001")
    email_record.delivered!(at: Time.parse("2024-05-05T16:00:00Z"))

    assert email_record.delivered?

    payload = {
      record_type: "Delivery",
      message_stream: "broadcast",
      message_id: "pm-nl-dup-001",
      recipient: "john@doe.com",
      delivered_at: "2024-05-05T17:00:00Z",
      details: "Duplicate newsletter delivery",
      tag: "newsletter-#{newsletter.id}"
    }

    assert_nothing_raised do
      perform_enqueued_jobs do
        Postmark::WebhookHandlerJob.perform_later(**payload)
      end
    end

    email_record.reload
    assert email_record.delivered?
    assert_equal "pm-nl-dup-001", email_record.postmark_message_id
  end

  # --- Unmatched webhooks ---

  test "unmatched webhook does not raise" do
    payload = {
      record_type: "Delivery",
      message_stream: "outbound",
      message_id: "pm-unknown-999",
      recipient: "nobody@nowhere.com",
      delivered_at: "2024-06-10T10:00:00Z",
      details: "Unknown",
      tag: "nonexistent-tag"
    }

    # Should not raise
    assert_nothing_raised do
      perform_enqueued_jobs do
        Postmark::WebhookHandlerJob.perform_later(**payload)
      end
    end
  end

  test "webhook with nil tag and no postmark_message_id match does not raise" do
    payload = {
      record_type: "Delivery",
      message_stream: "outbound",
      message_id: "pm-nil-tag-001",
      recipient: "john@doe.com",
      delivered_at: "2024-06-10T10:00:00Z",
      details: "No tag",
      tag: nil
    }

    assert_nothing_raised do
      perform_enqueued_jobs do
        Postmark::WebhookHandlerJob.perform_later(**payload)
      end
    end
  end

  # --- recompute_state! is called after webhook transitions ---

  test "delivery webhook triggers recompute_state! on parent delivery" do
    member = members(:john)
    delivery = MailDelivery.deliver!(
      member: member, mailable: invoices(:annual_fee), action: "created")
    email_record = delivery.emails.first
    email_record.update_column(:postmark_message_id, "pm-recompute-001")

    assert_equal "processing", delivery.state

    payload = {
      record_type: "Delivery",
      message_stream: "outbound",
      message_id: "pm-recompute-001",
      recipient: "john@doe.com",
      delivered_at: "2024-06-10T10:00:00Z",
      details: "Delivered",
      tag: "invoice-created"
    }

    perform_enqueued_jobs do
      Postmark::WebhookHandlerJob.perform_later(**payload)
    end

    assert_equal "delivered", delivery.reload.state
  end

  test "bounce webhook triggers recompute_state! on parent delivery" do
    member = members(:john)
    delivery = MailDelivery.deliver!(
      member: member, mailable: invoices(:annual_fee), action: "created")
    email_record = delivery.emails.first
    email_record.update_column(:postmark_message_id, "pm-recompute-002")

    assert_equal "processing", delivery.state

    payload = {
      record_type: "Bounce",
      message_stream: "outbound",
      message_id: "pm-recompute-002",
      email: "john@doe.com",
      bounced_at: "2024-06-10T10:00:00Z",
      details: "Bounce",
      tag: "invoice-created",
      type: "HardBounce",
      type_code: 1,
      description: "Bad address"
    }

    perform_enqueued_jobs do
      Postmark::WebhookHandlerJob.perform_later(**payload)
    end

    assert_equal "not_delivered", delivery.reload.state
  end
end
