# frozen_string_literal: true

require "test_helper"

class MailDelivery::EmailTest < ActiveSupport::TestCase
  test "has correct states" do
    assert_equal %w[processing delivered suppressed bounced], MailDelivery::Email::STATES
  end

  test "default state is processing" do
    member = members(:john)
    delivery = MailDelivery.deliver!(
      member: member, mailable: invoices(:annual_fee), action: "created")

    email = delivery.emails.first
    assert email.processing?
  end

  test "processing state enqueues process job for newsletter" do
    newsletter = newsletters(:simple)
    member = members(:john)

    assert_enqueued_with(job: MailDelivery::ProcessJob) do
      MailDelivery.deliver!(member: member, mailable: newsletter, action: "newsletter")
    end
  end

  test "processing state enqueues process job for template" do
    member = members(:john)

    assert_enqueued_with(job: MailDelivery::ProcessJob) do
      MailDelivery.deliver!(
        member: member, mailable: invoices(:annual_fee), action: "created")
    end
  end

  test "deliverable? returns true when email present and no suppressions" do
    member = members(:john)
    delivery = MailDelivery.deliver!(
      member: member, mailable: invoices(:annual_fee), action: "created")

    email = delivery.emails.first
    assert email.deliverable?
  end

  test "validates email presence" do
    member = members(:john)
    delivery = MailDelivery.create!(
      mailable_type: "Newsletter", mailable_ids: [ 1 ], action: "newsletter",
      member: member, state: :processing)
    email = delivery.emails.build(email: nil, state: :processing)

    assert_not email.valid?
    assert_includes email.errors[:email], "can't be blank"
  end

  test "deliverable? returns false when suppressions present" do
    member = members(:john)
    member.update!(emails: "john@bob.com, jojo@old.com")
    suppress_email("jojo@old.com", stream_id: "broadcast")

    perform_enqueued_jobs do
      MailDelivery.deliver!(member: member, mailable: newsletters(:simple), action: "newsletter")
    end

    suppressed_email = MailDelivery::Email.find_by(email: "jojo@old.com")
    assert_not suppressed_email.deliverable?
  end

  test "check_email_suppressions sets suppression data on creation" do
    member = members(:john)
    member.update!(emails: "john@bob.com, jojo@old.com")
    suppression = suppress_email("jojo@old.com", stream_id: "broadcast")

    perform_enqueued_jobs do
      MailDelivery.deliver!(member: member, mailable: newsletters(:simple), action: "newsletter")
    end

    suppressed_email = MailDelivery::Email.find_by(email: "jojo@old.com")
    assert_equal [ suppression.id ], suppressed_email.email_suppression_ids
    assert_equal %w[HardBounce], suppressed_email.email_suppression_reasons
  end

  test "suppressed email is marked as suppressed after processing" do
    member = members(:john)
    member.update!(emails: "jojo@old.com")
    suppress_email("jojo@old.com", stream_id: "broadcast")

    perform_enqueued_jobs do
      MailDelivery.deliver!(member: member, mailable: newsletters(:simple), action: "newsletter")
    end

    email = MailDelivery::Email.last
    assert email.suppressed?
    assert_equal "not_delivered", email.mail_delivery.reload.state
  end

  test "delivered! transitions from processing to delivered" do
    member = members(:john)
    delivery = MailDelivery.deliver!(
      member: member, mailable: invoices(:annual_fee), action: "created")

    email = delivery.emails.first
    now = Time.current

    email.delivered!(at: now, postmark_message_id: "abc-123", postmark_details: "OK")

    assert email.delivered?
    assert_equal now.to_i, email.delivered_at.to_i
    assert_equal "abc-123", email.postmark_message_id
    assert_equal "OK", email.postmark_details
  end

  test "delivered! calls recompute_state! on parent delivery" do
    member = members(:john)
    delivery = MailDelivery.deliver!(
      member: member, mailable: invoices(:annual_fee), action: "created")

    assert_equal "processing", delivery.state

    delivery.emails.first.delivered!(at: Time.current)

    assert_equal "delivered", delivery.reload.state
  end

  test "delivered! raises if not in processing state" do
    member = members(:john)
    delivery = MailDelivery.deliver!(
      member: member, mailable: invoices(:annual_fee), action: "created")

    email = delivery.emails.first
    email.delivered!(at: Time.current)
    assert email.delivered?

    assert_raises(InvalidTransitionError) do
      email.delivered!(at: Time.current)
    end
  end

  test "bounced! transitions from processing to bounced" do
    member = members(:john)
    delivery = MailDelivery.deliver!(
      member: member, mailable: invoices(:annual_fee), action: "created")

    email = delivery.emails.first
    now = Time.current

    email.bounced!(
      at: now,
      postmark_message_id: "def-456",
      bounce_type: "HardBounce",
      bounce_type_code: 1,
      bounce_description: "Bad address")

    assert email.bounced?
    assert_equal now.to_i, email.bounced_at.to_i
    assert_equal "def-456", email.postmark_message_id
    assert_equal "HardBounce", email.bounce_type
    assert_equal 1, email.bounce_type_code
    assert_equal "Bad address", email.bounce_description
  end

  test "bounced! calls recompute_state! on parent delivery" do
    member = members(:john)
    delivery = MailDelivery.deliver!(
      member: member, mailable: invoices(:annual_fee), action: "created")

    assert_equal "processing", delivery.state

    delivery.emails.first.bounced!(at: Time.current)

    assert_equal "not_delivered", delivery.reload.state
  end

  test "bounced! raises if not in processing state" do
    member = members(:john)
    delivery = MailDelivery.deliver!(
      member: member, mailable: invoices(:annual_fee), action: "created")

    email = delivery.emails.first
    email.delivered!(at: Time.current)

    assert_raises(InvalidTransitionError) do
      email.bounced!(at: Time.current)
    end
  end

  test "stale scope returns processing emails older than threshold" do
    member = members(:john)
    delivery = MailDelivery.deliver!(
      member: member, mailable: invoices(:annual_fee), action: "created")

    email = delivery.emails.first
    assert email.processing?
    assert_not_includes MailDelivery::Email.stale, email

    travel MailDelivery::Email::CONSIDER_STALE_AFTER + 1.minute do
      assert_includes MailDelivery::Email.stale, email
    end
  end

  test "state scopes filter correctly" do
    member = members(:john)

    d1 = MailDelivery.deliver!(
      member: member, mailable: invoices(:annual_fee), action: "created")
    d2 = MailDelivery.deliver!(
      member: member, mailable: member, mailable_type: "Member", action: "validated")

    e1 = d1.emails.first
    e2 = d2.emails.first

    e1.delivered!(at: Time.current)

    assert_includes MailDelivery::Email.delivered, e1
    assert_not_includes MailDelivery::Email.delivered, e2
    assert_includes MailDelivery::Email.processing, e2
    assert_not_includes MailDelivery::Email.processing, e1
  end

  test "unique index on mail_delivery_id and email" do
    member = members(:john)
    delivery = MailDelivery.deliver!(
      member: member, mailable: invoices(:annual_fee), action: "created")

    assert_raises(ActiveRecord::RecordNotUnique) do
      delivery.emails.create!(email: "john@doe.com", state: :processing)
    end
  end
end
