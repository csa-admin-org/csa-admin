# frozen_string_literal: true

require "test_helper"

class Support::TicketNotifyJobTest < ActiveJob::TestCase
  test "POSTs JSON to the webhook with the Authorization header" do
    admin = admins(:super)
    ticket = Support::Ticket.create!(
      priority: :medium,
      subject: "Need help",
      content: "Shop checkout is broken",
      context: "Member 42",
      emails: "alice@gmail.com",
      admin: admin)
    url = "https://webhook.example/support"

    stub_request(:post, url)
      .to_return(status: 200)

    Support::Ticket.stub(:webhook_url, url) do
      Support::Ticket.stub(:webhook_authorization, "Bearer test-sender-key") do
        with_env("GIT_REV" => "abc123") do
          perform_enqueued_jobs only: Support::TicketNotifyJob do
            Support::TicketNotifyJob.perform_later(ticket)
          end
        end
      end
    end

    assert_requested :post, url,
      headers: {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer test-sender-key"
      } do |request|
        body = JSON.parse(request.body)
        body.fetch("event") == "support.ticket.created" &&
          body.fetch("tenant") == "acme" &&
          body.dig("ticket", "id") == ticket.id &&
          body.dig("ticket", "subject") == "Need help" &&
          body.dig("ticket", "content") == "Shop checkout is broken" &&
          body.dig("ticket", "priority") == "medium" &&
          body.dig("admin", "id") == admin.id &&
          body.dig("admin", "email") == admin.email &&
          body.dig("org", "admin_host") == "admin.acme.test" &&
          body.dig("org", "members_host") == "members.acme.test" &&
          body.dig("org", "features") == Current.org.features.map(&:to_s) &&
          body.fetch("cc_emails") == [ "alice@gmail.com" ] &&
          body.dig("app", "revision") == "abc123" &&
          body.dig("app", "locale") == I18n.locale.to_s
      end
  end

  test "skips the POST when the webhook URL is blank" do
    ticket = Support::Ticket.create!(priority: :normal, subject: "Test", content: "Test")

    Support::Ticket.stub(:webhook_url, nil) do
      Support::Ticket.stub(:webhook_authorization, "Bearer test-sender-key") do
        perform_enqueued_jobs only: Support::TicketNotifyJob do
          Support::TicketNotifyJob.perform_later(ticket)
        end
      end
    end

    assert_not_requested :post, //
  end

  test "skips the POST when authorization is blank" do
    ticket = Support::Ticket.create!(priority: :normal, subject: "Test", content: "Test")
    url = "https://webhook.example/support"

    stub_request(:post, url)

    Support::Ticket.stub(:webhook_url, url) do
      Support::Ticket.stub(:webhook_authorization, nil) do
        perform_enqueued_jobs only: Support::TicketNotifyJob do
          Support::TicketNotifyJob.perform_later(ticket)
        end
      end
    end

    assert_not_requested :post, url
  end
end
