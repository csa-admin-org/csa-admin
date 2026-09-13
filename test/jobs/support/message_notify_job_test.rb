# frozen_string_literal: true

require "test_helper"

class Support::MessageNotifyJobTest < ActiveJob::TestCase
  test "POSTs JSON to the webhook with the Authorization header" do
    ticket = Support::Ticket.create!(
      priority: :medium,
      subject: "Need help",
      content: "Shop checkout is broken",
      admin: admins(:super))
    message = ticket.messages.first
    url = "https://webhook.example/support"

    stub_request(:post, url).to_return(status: 200)

    Support::Ticket.stub(:webhook_url, url) do
      Support::Ticket.stub(:webhook_authorization, "Bearer test-sender-key") do
        perform_enqueued_jobs only: Support::MessageNotifyJob do
          Support::MessageNotifyJob.perform_later(message)
        end
      end
    end

    assert_requested :post, url,
      headers: {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer test-sender-key"
      } do |request|
        body = JSON.parse(request.body)
        body.fetch("event") == "support.message.created" &&
          body.fetch("tenant") == "acme" &&
          body.fetch("ticket_id") == ticket.id &&
          body.fetch("message_id") == message.id &&
          body.fetch("author") == "admin"
      end
  end

  test "skips the POST when the webhook URL is blank" do
    ticket = Support::Ticket.create!(priority: :normal, subject: "Test", content: "Test")

    Support::Ticket.stub(:webhook_url, nil) do
      Support::Ticket.stub(:webhook_authorization, "Bearer test-sender-key") do
        perform_enqueued_jobs only: Support::MessageNotifyJob do
          Support::MessageNotifyJob.perform_later(ticket.messages.first)
        end
      end
    end

    assert_not_requested :post, //
  end
end
