# frozen_string_literal: true

require "rails_helper"

describe "Postmark Webhooks" do
  before { integration_session.host = "admin.acme.test" }

  describe "/postmark/webhooks" do
    def request(token: nil, params: {})
      token ||= Postmark.webhook_token
      authorization =
        ActionController::HttpAuthentication::Token.encode_credentials(token)

      headers = {
        "ACCEPT" => "application/json",
        "AUTHORIZATION" => authorization
      }
      post "/postmark/webhooks", headers: headers, params: params
    end

    specify "require valid token" do
      request(token: "not-the-good-one")
      expect(response.status).to eq 401
    end

    specify "handle delivery webhook" do
      delivery = create(:newsletter_delivery, :processed,
        email: "john@doe.com")

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

      expect {
        request(params: json)
        perform_enqueued_jobs
        expect(response.status).to eq 200
      }.to change { delivery.reload.state }.from("processing").to("delivered")

      expect(delivery).to have_attributes(
        delivered_at: Time.parse("2024-05-05T16:33:54.907025Z"),
        postmark_message_id: "883953f4-6105-42a2-a16a-77a8eac79483",
        postmark_details: "Test delivery webhook details")
    end

    specify "handle bounce webhook" do
      delivery = create(:newsletter_delivery, :processed,
        email: "john@doe.com")

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


      expect {
        request(params: json)
        perform_enqueued_jobs
        expect(response.status).to eq 200
      }.to change { delivery.reload.state }.from("processing").to("bounced")

      expect(delivery).to have_attributes(
        delivered_at: nil,
        bounced_at: Time.parse("2019-11-05T16:33:54.907025Z"),
        postmark_message_id: "883953f4-6105-42a2-a16a-77a8eac79483",
        postmark_details: "Test bounce details",
        bounce_type: "HardBounce",
        bounce_type_code: 1,
        bounce_description: "The server was unable to deliver your message (ex: unknown user, mailbox not found).")
    end
  end
end
