# frozen_string_literal: true

require "test_helper"

class Inbound::Postmark::WebhooksControllerTest < ActionDispatch::IntegrationTest
  def request(password: "secret", params: {})
    authorization = ActionController::HttpAuthentication::Basic.encode_credentials("postmark", password)
    previous = Tenant.current
    Tenant.disconnect
    with_env("APP_DOMAIN" => "acme.test") do
      Support::Ticket.stub(:inbound_webhook_password, "secret") do
        host! "inbound.acme.test"
        post "/postmark/webhooks",
          headers: { "AUTHORIZATION" => authorization },
          params: params,
          as: :json
      end
    end
  ensure
    Tenant.connect(previous) if previous
  end

  test "requires valid basic auth" do
    request(password: "wrong")
    assert_response :unauthorized
  end

  test "enqueues inbound job for a known tenant" do
    ticket = Support::Ticket.create!(
      priority: :normal, subject: "Help", content: "Opening", admin: admins(:external))

    assert_enqueued_jobs 1, only: Support::InboundJob do
      request(params: {
        "To" => ticket.inbound_email,
        "From" => admins(:external).email,
        "TextBody" => "Hello",
        "MessageID" => "pm-1"
      })
    end
    assert_response :success
  end

  test "returns 200 and drops unknown tenant" do
    assert_no_enqueued_jobs only: Support::InboundJob do
      request(params: {
        "To" => "ticket-deadbeef-unknown@support.csa-admin.org",
        "From" => "info@csa-admin.org",
        "TextBody" => "Hello"
      })
    end
    assert_response :success
  end

  test "returns 200 and drops demo tenant" do
    Tenant.stub(:exists?, true) do
      assert_no_enqueued_jobs only: Support::InboundJob do
        request(params: {
          "To" => "ticket-demo-en@support.csa-admin.org",
          "From" => "info@csa-admin.org",
          "TextBody" => "Hello"
        })
      end
    end
    assert_response :success
  end
end
