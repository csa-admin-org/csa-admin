# frozen_string_literal: true

require "test_helper"

class Postmark::WebhooksControllerControllerTest < ActionDispatch::IntegrationTest
  def request(token: nil, params: {})
    token ||= Postmark.webhook_token
    authorization = ActionController::HttpAuthentication::Token.encode_credentials(token)

    headers = {
      "ACCEPT" => "application/json",
      "AUTHORIZATION" => authorization
    }
    host! "admin.acme.test"
    post "/postmark/webhooks", headers: headers, params: params
  end

  test "require valid token" do
    request(token: "not-the-good-one")
    assert_response :unauthorized
  end

  test "handle broadcast delivery webhook" do
    newsletter = newsletters(:simple)
    member = members(:john)
    mail_delivery = MailDelivery.create!(
      mailable_type: "Newsletter", mailable_ids: [ newsletter.id ], action: "newsletter",
      member: member, state: :processing)
    email_record = mail_delivery.emails.create!(
      email: "john@doe.com",
      state: :processing,
      postmark_message_id: "883953f4-6105-42a2-a16a-77a8eac79483")

    json = JSON.parse(<<~JSON_STRING)
      {
        "MessageID": "883953f4-6105-42a2-a16a-77a8eac79483",
        "Recipient": "john@doe.com",
        "DeliveredAt": "2024-05-05T16:33:54.9070259Z",
        "Details": "Test delivery webhook details",
        "Tag": "newsletter-#{newsletter.id}",
        "ServerID": 23,
        "Metadata": {
          "a_key": "a_value",
          "b_key": "b_value"
        },
        "RecordType": "Delivery",
        "MessageStream": "broadcast"
      }
    JSON_STRING

    assert_changes -> { email_record.reload.state }, from: "processing", to: "delivered" do
      request(params: json)
      perform_enqueued_jobs
      assert_response :success
    end

    assert_equal Time.parse("2024-05-05T16:33:54.907025Z"), email_record.reload.delivered_at
    assert_equal "883953f4-6105-42a2-a16a-77a8eac79483", email_record.postmark_message_id
    assert_equal "Test delivery webhook details", email_record.postmark_details
  end

  test "handle broadcast bounce webhook" do
    newsletter = newsletters(:simple)
    member = members(:john)
    mail_delivery = MailDelivery.create!(
      mailable_type: "Newsletter", mailable_ids: [ newsletter.id ], action: "newsletter",
      member: member, state: :processing)
    email_record = mail_delivery.emails.create!(
      email: "john@doe.com",
      state: :processing,
      postmark_message_id: "883953f4-6105-42a2-a16a-77a8eac79483")

    json = JSON.parse(<<~JSON_STRING)
      {
        "RecordType": "Bounce",
        "MessageStream": "broadcast",
        "ID": 4323372036854775807,
        "Type": "HardBounce",
        "TypeCode": 1,
        "Name": "Hard bounce",
        "Tag": "newsletter-#{newsletter.id}",
        "MessageID": "883953f4-6105-42a2-a16a-77a8eac79483",
        "Metadata" : {
          "a_key" : "a_value",
          "b_key": "b_value"
        },
        "ServerID": 23,
        "Description": "The server was unable to deliver your message (ex: unknown user, mailbox not found).",
        "Details": "Test bounce details",
        "Email": "john@doe.com",
        "From": "sender@example.com",
        "BouncedAt": "2019-11-05T16:33:54.9070259Z",
        "DumpAvailable": true,
        "Inactive": true,
        "CanActivate": true,
        "Subject": "Test subject",
        "Content": "<Full dump of bounce>"
      }
    JSON_STRING

    assert_changes -> { email_record.reload.state }, from: "processing", to: "bounced" do
      request(params: json)
      perform_enqueued_jobs
      assert_response :success
    end

    assert_nil email_record.reload.delivered_at
    assert_equal Time.parse("2019-11-05T16:33:54.907025Z"), email_record.bounced_at
    assert_equal "883953f4-6105-42a2-a16a-77a8eac79483", email_record.postmark_message_id
    assert_equal "Test bounce details", email_record.postmark_details
    assert_equal "HardBounce", email_record.bounce_type
    assert_equal 1, email_record.bounce_type_code
    assert_equal "The server was unable to deliver your message (ex: unknown user, mailbox not found).", email_record.bounce_description
  end

  test "handle outbound delivery webhook via MailDelivery::Email postmark_message_id" do
    member = members(:john)
    delivery = MailDelivery.create!(
      mailable_type: "Invoice", mailable_ids: [ invoices(:annual_fee).id ], action: "created",
      member: member, state: :processing)
    email_record = delivery.emails.create!(
      email: "john@doe.com",
      state: :processing,
      postmark_message_id: "outbound-msg-001")

    json = JSON.parse(<<~JSON_STRING)
      {
        "MessageID": "outbound-msg-001",
        "Recipient": "john@doe.com",
        "DeliveredAt": "2024-06-10T10:00:00.0000000Z",
        "Details": "Outbound delivery details",
        "Tag": "invoice-created",
        "ServerID": 23,
        "RecordType": "Delivery",
        "MessageStream": "outbound"
      }
    JSON_STRING

    assert_changes -> { email_record.reload.state }, from: "processing", to: "delivered" do
      request(params: json)
      perform_enqueued_jobs(only: Postmark::WebhookHandlerJob)
      assert_response :success
    end

    assert_equal Time.parse("2024-06-10T10:00:00Z"), email_record.reload.delivered_at
    assert_equal "outbound-msg-001", email_record.postmark_message_id
    assert_equal "Outbound delivery details", email_record.postmark_details
  end

  test "handle outbound bounce webhook via MailDelivery::Email postmark_message_id" do
    member = members(:john)
    delivery = MailDelivery.create!(
      mailable_type: "Member", mailable_ids: [ member.id ], action: "validated",
      member: member, state: :processing)
    email_record = delivery.emails.create!(
      email: "john@doe.com",
      state: :processing,
      postmark_message_id: "outbound-msg-002")

    json = JSON.parse(<<~JSON_STRING)
      {
        "RecordType": "Bounce",
        "MessageStream": "outbound",
        "Type": "HardBounce",
        "TypeCode": 1,
        "Tag": "member-validated",
        "MessageID": "outbound-msg-002",
        "Description": "Unknown user",
        "Details": "Outbound bounce details",
        "Email": "john@doe.com",
        "BouncedAt": "2024-06-10T10:05:00.0000000Z"
      }
    JSON_STRING

    assert_changes -> { email_record.reload.state }, from: "processing", to: "bounced" do
      request(params: json)
      perform_enqueued_jobs(only: Postmark::WebhookHandlerJob)
      assert_response :success
    end

    email_record.reload
    assert_equal Time.parse("2024-06-10T10:05:00Z"), email_record.bounced_at
    assert_equal "outbound-msg-002", email_record.postmark_message_id
    assert_equal "Outbound bounce details", email_record.postmark_details
    assert_equal "HardBounce", email_record.bounce_type
    assert_equal 1, email_record.bounce_type_code
    assert_equal "Unknown user", email_record.bounce_description
  end

  test "unsupported record type returns 200 without processing" do
    json = JSON.parse(<<~JSON_STRING)
      {
        "RecordType": "Open",
        "MessageStream": "outbound",
        "MessageID": "ignored-msg"
      }
    JSON_STRING

    assert_no_enqueued_jobs(only: Postmark::WebhookHandlerJob) do
      request(params: json)
      assert_response :success
    end
  end

  test "unsupported message stream returns 200 without processing" do
    json = JSON.parse(<<~JSON_STRING)
      {
        "RecordType": "Delivery",
        "MessageStream": "inbound",
        "MessageID": "ignored-msg"
      }
    JSON_STRING

    assert_no_enqueued_jobs(only: Postmark::WebhookHandlerJob) do
      request(params: json)
      assert_response :success
    end
  end
end
