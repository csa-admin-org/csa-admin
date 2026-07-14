# frozen_string_literal: true

require "test_helper"

class SessionMailerTest < ActionMailer::TestCase
  setup { postmark_client.reset! }

  test "new member session email" do
    session = Session.new(
      member: Member.new(language: "fr"),
      email: "example@csa-admin.org")
    mail = SessionMailer.with(
      session: session,
      session_url: "https://example.com/session/token",
    ).new_member_session_email

    assert_equal "Connexion à votre compte", mail.subject
    assert_equal %w[ example@csa-admin.org ], mail.to
    assert_equal "session-member", mail.tag

    assert_includes mail.body.to_s, "Accéder à mon compte"
    assert_includes mail.body.to_s, "https://example.com/session/token"
    assert_equal "Acme <info@acme.test>", mail[:from].decoded
  end

  test "inactive recipient syncs suppressions without failing delivery" do
    freeze_time
    session = create_session(members(:john))
    postmark_client.dump_suppressions_response = [ {
      email_address: session.email,
      suppression_reason: "HardBounce",
      origin: "Recipient",
      created_at: Time.current.to_s
    } ]
    postmark_request = stub_request(:post, "https://api.postmarkapp.com/email").to_return(
      status: 422,
      body: {
        ErrorCode: 406,
        Message: "Found inactive addresses: #{session.email}. Inactive recipients cannot receive email."
      }.to_json,
      headers: { "Content-Type" => "application/json" })
    delivery = SessionMailer.with(
      session: session,
      session_url: "https://example.com/session/token"
    ).new_member_session_email
    delivery.message.delivery_method(Mail::Postmark, api_token: "test-token")

    assert_nothing_raised { delivery.deliver_now }

    assert_requested postmark_request
    assert EmailSuppression.outbound.active.exists?(email: session.email)

    subsequent_session = Session.new(
      member_email: session.email,
      remote_addr: "127.0.0.1",
      user_agent: "a browser user agent")
    assert_not subsequent_session.valid?
    assert subsequent_session.errors.added?(:email, :suppressed)
  end

  test "new admin session email" do
    session = Session.new(
      admin: Admin.new(language: "fr"),
      email: "example@csa-admin.org")
    mail = SessionMailer.with(
      session: session,
      session_url: "https://example.com/session/token",
    ).new_admin_session_email

    assert_equal "Connexion à votre compte admin", mail.subject
    assert_equal %w[ example@csa-admin.org ], mail.to
    assert_equal "session-admin", mail.tag

    assert_includes mail.body.to_s, "Accéder à mon compte admin"
    assert_includes mail.body.to_s, "https://example.com/session/token"
    assert_equal "Acme <info@acme.test>", mail[:from].decoded
  end
end
