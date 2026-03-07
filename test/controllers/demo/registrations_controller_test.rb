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

  test "GET /demo renders form on demo tenant" do
    in_demo_tenant do
      get new_demo_registration_path

      assert_response :success
      assert_select "h1", "CSA Admin — #{I18n.t('demo.registrations.new.title')}"
      assert_select "input[name='demo_registration[name]']"
      assert_select "input[name='demo_registration[email]']"
      assert_select "textarea[name='demo_registration[note]']"
    end
  end

  test "POST /demo redirects to login on non-demo tenant" do
    post demo_registrations_path, params: {
      demo_registration: { name: "Test", email: "test@example.com" }
    }

    assert_redirected_to login_path
  end

  test "POST /demo with valid params creates admin and redirects" do
    in_demo_tenant do
      assert_enqueued_emails 2 do
        post demo_registrations_path, params: {
          demo_registration: {
            name: "Alice Johnson",
            email: "alice@example.com",
            note: "Green Valley CSA"
          }
        }
      end

      assert_redirected_to login_path
      assert_equal I18n.t("sessions.flash.initiated"), flash[:notice]
    end
  end

  test "POST /demo with invalid params renders form with errors" do
    in_demo_tenant do
      assert_no_enqueued_emails do
        post demo_registrations_path, params: {
          demo_registration: { name: "", email: "" }
        }
      end

      assert_response :unprocessable_entity
    end
  end

  private

  def in_demo_tenant
    Tenant.stub(:demo?, true) do
      Tenant.stub(:demo_language, "en") do
        Tenant.stub(:admin_host, "admin.csa-admin.org") do
          yield
        end
      end
    end
  end
end
