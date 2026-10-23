# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class Demo::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "admin.acme.test"
  end

  test "GET /demo redirects to login on non-demo tenant" do
    get new_demo_registration_path

    assert_redirected_to login_path
  end

  test "GET /login on a non-demo tenant does not show the demo language switch" do
    get login_path

    assert_response :success
    assert_select ".admin-locales", count: 0
  end

  test "GET /demo renders form on demo tenant" do
    in_demo_tenant do
      get new_demo_registration_path

      assert_response :success
      assert_select "h1", "CSA Admin — #{I18n.t('demo.registrations.new.title')}"
      assert_select "input[name='demo_registration[name]']"
      assert_select "input[name='demo_registration[email]']"
      assert_select "textarea[name='demo_registration[message]']"
    end
  end

  test "GET /demo links the other demo hosts and marks the current language" do
    in_demo_tenant do
      get new_demo_registration_path

      assert_demo_language_switch(path: new_demo_registration_path)
    end
  end

  test "GET /login on a demo tenant links the other demo logins" do
    in_demo_tenant do
      get login_path

      assert_demo_language_switch(path: login_path)
    end
  end

  test "POST /demo redirects to login on non-demo tenant" do
    post demo_registrations_path, params: {
      demo_registration: { name: "Test", email: "test@example.com" }
    }

    assert_redirected_to login_path
  end

  test "POST /demo with valid params emails a redeemable invite and stays logged out" do
    in_demo_tenant do
      assert_enqueued_emails 1 do
        post demo_registrations_path, params: {
          "cap-token" => cap_token,
          demo_registration: {
            name: "Alice Johnson",
            email: "alice@example.com",
            message: "Green Valley CSA"
          }
        }
      end

      admin = Admin.find_by!(email: "alice@example.com")
      invite_session = admin.sessions.sole
      assert_equal "Green Valley CSA", admin.demo_message
      assert_nil admin.demo_registration_notification_sent_at
      assert_redirected_to login_path
      assert_equal I18n.t("demo.registrations.flash.created"), flash[:notice]
      assert_not cookies[:session_id].present?
      assert_nil invite_session.last_used_at

      follow_redirect!
      assert_response :success
      assert_nil invite_session.reload.last_used_at

      token = invite_session.generate_token_for(:demo_invite)
      assert_equal invite_session, Session.redeem_token(token, owner_type: :admin)
    end
  end

  test "POST /demo without cap token returns unprocessable entity" do
    in_demo_tenant do
      assert_no_enqueued_emails do
        post demo_registrations_path, params: {
          demo_registration: {
            name: "Alice Johnson",
            email: "alice@example.com"
          }
        }
      end

      assert_response :unprocessable_entity
    end
  end

  test "POST /demo with invalid params renders form with errors" do
    in_demo_tenant do
      assert_no_enqueued_emails do
        post demo_registrations_path, params: {
          "cap-token" => cap_token,
          demo_registration: { name: "", email: "" }
        }
      end

      assert_response :unprocessable_entity
      assert_demo_language_switch(path: "/demo")
    end
  end

  private

  def in_demo_tenant
    Tenant.stub(:demo?, true) do
      Tenant.stub(:demo_language, "en") do
        Tenant.stub(:admin_host, "admin.csa-admin.org") do
          Tenant.stub(:demo_admin_hosts, demo_admin_hosts) do
            yield
          end
        end
      end
    end
  end

  def demo_admin_hosts
    {
      "en" => "admin.csa-admin.org",
      "fr" => "admin.acp-admin.ch",
      "de" => "admin.solawi-admin.org"
    }
  end

  def assert_demo_language_switch(path:)
    assert_select ".admin-locale-link[aria-current=page]", text: "en", count: 1
    assert_select "a.admin-locale-link", text: "en", count: 0
    assert_select "a.admin-locale-link[href=?]", "https://admin.acp-admin.ch#{path}", text: "fr"
    assert_select "a.admin-locale-link[href=?]", "https://admin.solawi-admin.org#{path}", text: "de"
    assert_select "a[href*='?locale']", count: 0
  end
end
