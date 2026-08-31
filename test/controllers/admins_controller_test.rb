# frozen_string_literal: true

require "test_helper"

class AdminsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "admin.acme.test"
  end

  def login(admin)
    session = Session.create!(
      admin_email: admin.email,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
  end

  test "index shows a suppressed admin email once with reactivate" do
    admin = admins(:external)
    suppression = suppress_email(admin.email)
    login admins(:super)

    get admins_path

    assert_response :success
    assert_select "tr#admin_#{admin.id} td[data-column=email]" do
      assert_select "s", text: admin.email, count: 1
      assert_select "a[href=?]", "mailto:#{admin.email}", count: 0
      assert_select ".status-tag", text: /hard bounce/i
      assert_select "form[action=?]", email_suppression_path(suppression)
    end
  end

  test "edit shows resend invitation when the admin never signed in" do
    login admins(:super)

    get edit_admin_path(admins(:external))

    assert_response :success
    assert_select "form[action='#{invite_admin_path(admins(:external))}']"
  end

  test "edit hides resend invitation after the admin signed in" do
    admin = admins(:external)
    Session.create!(
      admin: admin,
      email: admin.email,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    login admins(:super)

    get edit_admin_path(admin)

    assert_response :success
    assert_select "form[action='#{invite_admin_path(admin)}']", false
  end

  test "invite resends the invitation email" do
    login admins(:super)

    assert_enqueued_emails 1 do
      post invite_admin_path(admins(:external))
    end

    assert_redirected_to admins_path
  end
end
