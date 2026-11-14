# frozen_string_literal: true

require "test_helper"

class MissionControl::TenantsControllerTest < ActionDispatch::IntegrationTest
  def authenticate!
    credentials = ActionController::HttpAuthentication::Basic.encode_credentials("mc", "password")
    @auth_headers = { "Authorization" => credentials }
  end

  setup { authenticate! }

  test "lists tenants from config without switching org" do
    get mc_root_url(host: "mc.acme.test"), headers: @auth_headers

    assert_response :success
    assert_select ".mc-brand-title", text: "CSA Admin"
    assert_select ".mc-theme-toggle"
    assert_select "html[data-theme=system]"
    assert_select ".mc-tenant-name", text: "acme"
    assert_select ".mc-tenant-name", text: "beta"
    assert_select "a.mc-portal-link[href=?]", "https://admin.acme.test"
    assert_select "a.mc-portal-link[href=?]", "https://members.acme.test"
    assert_select ".mc-tenant-aliases", count: 0
  end

  test "requires http basic outside development" do
    get mc_root_url(host: "mc.acme.test")

    assert_response :unauthorized
  end
end
