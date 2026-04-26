# frozen_string_literal: true

require "test_helper"

class Members::AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "members.acme.test"
  end

  def login(member)
    session = Session.create!(
      member: member,
      email: member.emails_array.first,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
    session
  end

  def login_as_admin_originated(member, admin: admins(:ultra))
    session = Session.create!(
      admin: admin,
      member: member,
      email: admin.email,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
    session
  end

  test "edit renders for an admin-originated session" do
    login_as_admin_originated(members(:john))

    get edit_members_account_path

    assert_response :success
    assert_select "form[action='#{members_account_path}']"
  end

  test "update is blocked for an admin-originated session" do
    member = members(:john)
    login_as_admin_originated(member)

    assert_no_changes -> { member.reload.name } do
      patch members_account_path,
        params: { member: { name: "John Updated" } },
        headers: { "HTTP_REFERER" => edit_members_account_path }
    end

    assert_redirected_to edit_members_account_path
    assert_equal I18n.t("members.read_only_sessions.alert"), flash[:alert]
  end

  test "update is allowed for an admin-originated session in development" do
    member = members(:john)
    login_as_admin_originated(member)

    original_env = Rails.instance_variable_get(:@_env)

    begin
      Rails.instance_variable_set(:@_env, ActiveSupport::EnvironmentInquirer.new("development"))

      assert_changes -> { member.reload.name }, to: "John Updated" do
        patch members_account_path, params: {
          member: { name: "John Updated" }
        }
      end
    ensure
      Rails.instance_variable_set(:@_env, original_env)
    end

    assert_redirected_to members_account_path
  end

  test "logout remains allowed for an admin-originated session" do
    session = login_as_admin_originated(members(:john))

    delete members_logout_path

    assert_redirected_to members_login_path
    assert session.reload.revoked?
  end
end
