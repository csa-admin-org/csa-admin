# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class DemoMailInterceptorTest < ActiveSupport::TestCase
  test "allows authentication emails in demo mode" do
    with_tenant("demo-en") do
      DemoMailInterceptor::ALLOWED_TAGS.each do |tag|
        message = Mail.new(to: "test@example.com", from: "sender@example.com")
        message[:tag] = tag

        DemoMailInterceptor.delivering_email(message)

        assert message.perform_deliveries, "#{tag} emails should be delivered in demo mode"
      end
    end
  end

  test "blocks non-authentication emails in demo mode" do
    with_tenant("demo-en") do
      message = Mail.new(
        to: "recipient@example.com",
        from: "sender@example.com",
        subject: "Test email"
      )
      message[:tag] = "invoice-created"

      DemoMailInterceptor.delivering_email(message)

      assert_not message.perform_deliveries, "invoice-created emails should be blocked in demo mode"
    end
  end

  test "blocks emails without tags in demo mode" do
    with_tenant("demo-en") do
      message = Mail.new(
        to: "recipient@example.com",
        from: "sender@example.com",
        subject: "Test email"
      )

      DemoMailInterceptor.delivering_email(message)

      assert_not message.perform_deliveries, "emails without tags should be blocked in demo mode"
    end
  end

  test "allows all emails when not in demo mode" do
    with_tenant("acme") do
      message = Mail.new(
        to: "recipient@example.com",
        from: "sender@example.com",
        subject: "Test email"
      )
      message[:tag] = "invoice-created"

      DemoMailInterceptor.delivering_email(message)

      assert message.perform_deliveries, "all emails should be delivered in non-demo mode"
    end
  end
end

class DemoMailInterceptorIntegrationTest < ActionMailer::TestCase
  test "blocks invoice emails in demo mode" do
    template = mail_templates(:invoice_created)
    invoice = invoices(:annual_fee)

    Tenant.stub(:demo?, true) do
      assert_no_emails do
        InvoiceMailer.with(
          template: template,
          invoice: invoice
        ).created_email.deliver_now
      end
    end
  end

  test "allows session emails in demo mode" do
    session = Session.new(
      member: Member.new(language: "en"),
      email: "test@example.com")

    Tenant.stub(:demo?, true) do
      assert_emails 1 do
        SessionMailer.with(
          session: session,
          session_url: "https://example.com/session/token"
        ).new_member_session_email.deliver_now
      end
    end
  end
end
