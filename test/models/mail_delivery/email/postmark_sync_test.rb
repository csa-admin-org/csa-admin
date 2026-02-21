# frozen_string_literal: true

require "test_helper"

class MailDelivery::Email::PostmarkSyncTest < ActiveSupport::TestCase
  setup { postmark_client.reset! }

  # --- sync_from_postmark! ---

  test "sync_from_postmark! transitions to delivered when Postmark has Delivered event" do
    member = members(:john)
    delivery = MailDelivery.deliver!(
      member: member, mailable: invoices(:annual_fee), action: "created")
    email = delivery.emails.first
    email.update_column(:postmark_message_id, "pm-sync-001")

    postmark_client.get_message_responses["pm-sync-001"] = {
      status: "Sent",
      message_events: [
        {
          "Type" => "Delivered",
          "Recipient" => "john@doe.com",
          "ReceivedAt" => "2024-06-10T10:00:00Z",
          "Details" => { "DeliveryMessage" => "Delivered OK" }
        }
      ]
    }

    email.sync_from_postmark!

    email.reload
    assert email.delivered?
    assert_equal Time.parse("2024-06-10T10:00:00Z"), email.delivered_at
    assert_equal "Delivered OK", email.postmark_details
  end

  test "sync_from_postmark! transitions to bounced when Postmark has Bounced event" do
    member = members(:john)
    delivery = MailDelivery.deliver!(
      member: member, mailable: invoices(:annual_fee), action: "created")
    email = delivery.emails.first
    email.update_column(:postmark_message_id, "pm-sync-002")

    postmark_client.get_message_responses["pm-sync-002"] = {
      status: "Sent",
      message_events: [
        {
          "Type" => "Bounced",
          "Recipient" => "john@doe.com",
          "ReceivedAt" => "2024-06-10T10:00:00Z",
          "Details" => { "BounceID" => 42 }
        }
      ]
    }
    postmark_client.get_bounce_responses[42] = {
      bounced_at: "2024-06-10T10:05:00Z",
      message_id: "pm-sync-002",
      details: "Bounce details",
      type: "HardBounce",
      type_code: 1,
      description: "Unknown user"
    }

    email.sync_from_postmark!

    email.reload
    assert email.bounced?
    assert_equal Time.parse("2024-06-10T10:05:00Z"), email.bounced_at
    assert_equal "HardBounce", email.bounce_type
    assert_equal 1, email.bounce_type_code
    assert_equal "Unknown user", email.bounce_description
  end

  test "sync_from_postmark! is a no-op when already delivered" do
    member = members(:john)
    delivery = MailDelivery.deliver!(
      member: member, mailable: invoices(:annual_fee), action: "created")
    email = delivery.emails.first
    email.update_column(:postmark_message_id, "pm-sync-003")
    email.delivered!(at: Time.current)

    email.sync_from_postmark!

    assert email.delivered?
    assert_empty postmark_client.calls
  end

  test "sync_from_postmark! is a no-op when Postmark has no events" do
    member = members(:john)
    delivery = MailDelivery.deliver!(
      member: member, mailable: invoices(:annual_fee), action: "created")
    email = delivery.emails.first
    email.update_column(:postmark_message_id, "pm-sync-004")

    postmark_client.get_message_responses["pm-sync-004"] = {
      status: "Sent",
      message_events: []
    }

    email.sync_from_postmark!

    assert email.processing?
  end

  test "sync_from_postmark! is a no-op when Postmark status is not Sent" do
    member = members(:john)
    delivery = MailDelivery.deliver!(
      member: member, mailable: invoices(:annual_fee), action: "created")
    email = delivery.emails.first
    email.update_column(:postmark_message_id, "pm-sync-005")

    postmark_client.get_message_responses["pm-sync-005"] = {
      status: "Queued",
      message_events: []
    }

    email.sync_from_postmark!

    assert email.processing?
  end

  # --- sync_stale_from_postmark! ---

  test "sync_stale_from_postmark! syncs only stale processing emails" do
    member = members(:john)
    delivery = MailDelivery.deliver!(
      member: member, mailable: invoices(:annual_fee), action: "created")
    email = delivery.emails.first
    email.update_column(:postmark_message_id, "pm-stale-001")

    postmark_client.get_message_responses["pm-stale-001"] = {
      status: "Sent",
      message_events: [
        {
          "Type" => "Delivered",
          "Recipient" => "john@doe.com",
          "ReceivedAt" => "2024-06-10T10:00:00Z",
          "Details" => { "DeliveryMessage" => "Delivered OK" }
        }
      ]
    }

    # Not stale yet — should not be synced
    MailDelivery::Email.sync_stale_from_postmark!
    assert email.reload.processing?

    # Now stale — should be synced
    travel MailDelivery::Email::CONSIDER_STALE_AFTER + 1.minute do
      MailDelivery::Email.sync_stale_from_postmark!
      assert email.reload.delivered?
    end
  end

  test "sync_stale_from_postmark! skips emails without postmark_message_id" do
    member = members(:john)
    delivery = MailDelivery.create!(
      mailable_type: "Newsletter", mailable_ids: [ 1 ], action: "newsletter",
      member: member, state: :processing)
    email = delivery.emails.create!(
      email: "john@doe.com", state: :processing, postmark_message_id: nil)

    travel MailDelivery::Email::CONSIDER_STALE_AFTER + 1.minute do
      MailDelivery::Email.sync_stale_from_postmark!
      assert email.reload.processing?
      assert_empty postmark_client.calls
    end
  end

  test "sync_stale_from_postmark! continues on error for individual emails" do
    member = members(:john)

    d1 = MailDelivery.deliver!(
      member: member, mailable: invoices(:annual_fee), action: "created")
    email1 = d1.emails.first
    email1.update_column(:postmark_message_id, "pm-err-001")

    d2 = MailDelivery.deliver!(
      member: member, mailable: member, mailable_type: "Member", action: "validated")
    email2 = d2.emails.first
    email2.update_column(:postmark_message_id, "pm-err-002")

    # First email will raise, second will succeed
    postmark_client.get_message_responses["pm-err-001"] = nil # will cause NoMethodError
    postmark_client.get_message_responses["pm-err-002"] = {
      status: "Sent",
      message_events: [
        {
          "Type" => "Delivered",
          "Recipient" => "john@doe.com",
          "ReceivedAt" => "2024-06-10T10:00:00Z",
          "Details" => { "DeliveryMessage" => "OK" }
        }
      ]
    }

    travel MailDelivery::Email::CONSIDER_STALE_AFTER + 1.minute do
      MailDelivery::Email.sync_stale_from_postmark!
      assert email1.reload.processing?
      assert email2.reload.delivered?
    end
  end
end
