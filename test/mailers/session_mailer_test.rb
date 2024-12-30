# frozen_string_literal: true

require "test_helper"

class SessionMailerTest < ActionMailer::TestCase
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
