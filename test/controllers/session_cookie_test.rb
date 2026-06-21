# frozen_string_literal: true

require "test_helper"

class SessionTrackingProbeController < ApplicationController
  skip_before_action :set_locale

  def swap
    current_session
    sign_in_session(Session.find(params[:id]))
    render plain: Current.session.id.to_s
  end

  def clear
    Current.session = Session.find(params[:id])
    delete_session_cookie
    render plain: Current.session.inspect
  end
end

class SessionTrackingTest < ActionController::TestCase
  tests SessionTrackingProbeController

  setup do
    @routes = ActionDispatch::Routing::RouteSet.new
    @routes.draw do
      get "session_tracking_probe/:id", to: "session_tracking_probe#swap"
      get "session_tracking_probe/:id/clear", to: "session_tracking_probe#clear"
    end
  end

  test "sign in replaces stale current session in the same request" do
    stale_session = create_session(members(:jane))
    replacement_session = create_session(members(:john))
    cookies.encrypted[:session_id] = stale_session.id

    get :swap, params: { id: replacement_session.id }

    assert_response :success
    assert_equal replacement_session.id.to_s, response.body
  end

  test "deleting session cookie clears current session in the same request" do
    session = create_session(members(:john))

    get :clear, params: { id: session.id }

    assert_response :success
    assert_equal "nil", response.body
  end
end

class SessionCookieTest < ActionDispatch::IntegrationTest
  test "admin login writes auth cookie with explicit policy" do
    host! "admin.acme.test"
    session = create_admin_session(admins(:ultra))

    get "/sessions/#{session.generate_token_for(:redeem)}"

    assert_session_cookie
  end

  test "admin-originated member login writes auth cookie with explicit policy" do
    host! "members.acme.test"
    session = create_admin_originated_member_session(admins(:ultra), members(:john))

    get "/sessions/#{session.generate_token_for(:redeem)}"

    assert_session_cookie
  end

  test "expired admin session does not redirect away from login page" do
    host! "admin.acme.test"
    session = create_admin_session(admins(:ultra))

    get "/sessions/#{session.generate_token_for(:redeem)}"
    expire_session(session)
    get login_path

    assert_response :success
    assert_select "form[action=?]", sessions_path
  end

  test "expired member session does not redirect away from login page" do
    host! "members.acme.test"
    session = create_member_session(members(:john))

    get "/sessions/#{session.generate_token_for(:redeem)}"
    expire_session(session)
    get members_login_path

    assert_response :success
    assert_select "form[action=?]", members_sessions_path
  end

  test "expired admin-originated member session does not redirect away from login page" do
    host! "members.acme.test"
    session = create_admin_originated_member_session(admins(:ultra), members(:john))

    get "/sessions/#{session.generate_token_for(:redeem)}"
    expire_session(session)
    get members_login_path

    assert_response :success
    assert_select "form[action=?]", members_sessions_path
  end

  test "expired admin session redirects protected pages with expired alert" do
    host! "admin.acme.test"
    session = create_admin_session(admins(:ultra))

    get "/sessions/#{session.generate_token_for(:redeem)}"
    expire_session(session)
    get root_path

    assert_redirected_to login_path
    assert_equal I18n.t("sessions.flash.expired"), flash[:alert]
  end

  test "expired member session redirects protected pages with expired alert" do
    host! "members.acme.test"
    session = create_member_session(members(:john))

    get "/sessions/#{session.generate_token_for(:redeem)}"
    expire_session(session)
    get members_member_path

    assert_redirected_to members_login_path
    assert_equal I18n.t("sessions.flash.expired"), flash[:alert]
  end

  test "development admin auto sign in does not run on members host" do
    host! "members.acme.test"

    with_development_auto_admin_sign_in do
      assert_no_admin_only_session_created { get members_login_path }
    end

    assert_response :success
  end

  test "admin-originated member login survives stale member cookie in development" do
    host! "members.acme.test"
    member = members(:john)
    stale_session = create_member_session(members(:jane))
    session = create_admin_originated_member_session(admins(:ultra), member)

    get "/sessions/#{stale_session.generate_token_for(:redeem)}"

    with_development_auto_admin_sign_in do
      assert_no_admin_only_session_created { get "/sessions/#{session.generate_token_for(:redeem)}" }
    end

    assert_redirected_to members_member_path
    assert_session_cookie

    follow_redirect!
    assert_not_equal members_login_url, response.location

    get members_account_path
    assert_response :success
    assert_select "span", text: member.name
  end

  private

  def assert_session_cookie
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

  def create_member_session(member)
    Session.create!(
      member_email: member.emails_array.first,
      remote_addr: "127.0.0.1",
      user_agent: "a browser user agent")
  end

  def create_admin_originated_member_session(admin, member)
    Session.create!(
      admin: admin,
      member: member,
      email: admin.email,
      remote_addr: "127.0.0.1",
      user_agent: "a browser user agent")
  end

  def assert_no_admin_only_session_created(&block)
    assert_no_difference -> { admin_only_sessions.count }, &block
  end

  def expire_session(session)
    expiration = session.admin_originated? ? 6.hours : Session::EXPIRATION
    session.update!(created_at: expiration.ago - 1.second)
  end

  def with_development_auto_admin_sign_in
    env = { "AUTO_SIGN_IN_ADMIN_EMAIL" => admins(:ultra).email }
    with_env(env) { with_rails_env("development") { with_demo_tenant { yield } } }
  end

  def admin_only_sessions
    Session.where.not(admin_id: nil).where(member_id: nil)
  end
end
