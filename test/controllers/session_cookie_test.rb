# frozen_string_literal: true

require "test_helper"

class SessionCookieTest < ActionDispatch::IntegrationTest
  test "admin login writes auth cookie with explicit policy" do
    host! "admin.acme.test"
    session = create_admin_session(admins(:ultra))

    get "/sessions/#{session.generate_token_for(:redeem)}"

    assert_session_cookie(session)
  end

  test "admin-originated member login writes auth cookie with explicit policy" do
    host! "members.acme.test"
    session = Session.create!(
      admin: admins(:ultra),
      member: members(:john),
      email: admins(:ultra).email,
      remote_addr: "127.0.0.1",
      user_agent: "a browser user agent")

    get "/sessions/#{session.generate_token_for(:redeem)}"

    assert_session_cookie(session)
  end

  private

  def assert_session_cookie(session)
    cookie = session_cookie_header

    assert cookie
    assert_includes cookie, "session_id="
    assert_includes cookie_attributes, "path=/"
    assert_includes cookie_attributes, "httponly"
    assert_includes cookie_attributes, "samesite=lax"
    assert_not cookie_attributes.any? { |attribute| attribute.start_with?("expires=", "max-age=") }
  end

  def session_cookie_header
    Array(response.headers["Set-Cookie"]).find { |cookie| cookie.start_with?("session_id=") }
  end

  def cookie_attributes
    session_cookie_header.split(";").drop(1).map { |attribute| attribute.strip.downcase }
  end

  def create_admin_session(admin)
    Session.create!(
      admin_email: admin.email,
      remote_addr: "127.0.0.1",
      user_agent: "a browser user agent")
  end
end
