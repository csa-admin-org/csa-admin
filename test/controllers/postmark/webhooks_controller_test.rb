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

  test "handle delivery webhook" do
    delivery = newsletter_deliveries(:simple_john)
    json = JSON.parse(<<~JSON_STRING)
      {
        "MessageID": "883953f4-6105-42a2-a16a-77a8eac79483",
        "Recipient": "john@doe.com",
        "DeliveredAt": "2024-05-05T16:33:54.9070259Z",
        "Details": "Test delivery webhook details",
        "Tag": "#{delivery.tag}",
        "ServerID": 23,
        "Metadata": {
          "a_key": "a_value",
          "b_key": "b_value"
        },
        "RecordType": "Delivery",
        "MessageStream": "broadcast"
      }
    JSON_STRING

    assert_changes -> { delivery.reload.state }, from: "processing", to: "delivered" do
      request(params: json)
      perform_enqueued_jobs
      assert_response :success
    end

    assert_equal Time.parse("2024-05-05T16:33:54.907025Z"), delivery.reload.delivered_at
    assert_equal "883953f4-6105-42a2-a16a-77a8eac79483", delivery.postmark_message_id
    assert_equal "Test delivery webhook details", delivery.postmark_details
  end

  test "handle bounce webhook" do
    delivery = newsletter_deliveries(:simple_john)
    json = JSON.parse(<<~JSON_STRING)
      {
        "RecordType": "Bounce",
        "MessageStream": "broadcast",
        "ID": 4323372036854775807,
        "Type": "HardBounce",
        "TypeCode": 1,
        "Name": "Hard bounce",
        "Tag": "#{delivery.tag}",
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

    assert_changes -> { delivery.reload.state }, from: "processing", to: "bounced" do
      request(params: json)
      perform_enqueued_jobs
      assert_response :success
    end

    assert_nil delivery.reload.delivered_at
    assert_equal Time.parse("2019-11-05T16:33:54.907025Z"), delivery.bounced_at
    assert_equal "883953f4-6105-42a2-a16a-77a8eac79483", delivery.postmark_message_id
    assert_equal "Test bounce details", delivery.postmark_details
    assert_equal "HardBounce", delivery.bounce_type
    assert_equal 1, delivery.bounce_type_code
    assert_equal "The server was unable to deliver your message (ex: unknown user, mailbox not found).", delivery.bounce_description
  end
end
