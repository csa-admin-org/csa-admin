# frozen_string_literal: true

require "application_system_test_case"

class MissionControl::TenantsTest < ApplicationSystemTestCase
  def authenticate!
    credentials = ActionController::HttpAuthentication::Basic.encode_credentials("mc", "password")
    page.driver.header "Authorization", credentials
  end

  test "lists tenants with admin and members links" do
    authenticate!

    visit "/"

    assert_selector ".mc-tenant-name", text: "acme"
    assert_selector ".mc-tenant-name", text: "beta"
    assert_link "Admin", href: "https://admin.acme.test"
    assert_link "Members", href: "https://members.acme.test"
    assert_selector ".mc-brand-title", text: "CSA Admin"
    assert_selector ".mc-filter-input"
    assert_selector ".mc-theme-toggle"
    assert_no_selector ".mc-tenant-aliases"
  end
end
