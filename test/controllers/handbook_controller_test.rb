# frozen_string_literal: true

require "test_helper"

class HandbookControllerTest < ActionDispatch::IntegrationTest
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

  test "renders page title once with a non-clickable handbook breadcrumb" do
    login admins(:super)

    get handbook_page_path(:getting_started)

    assert_response :success
    assert_select "h2", text: "Getting Started"
    assert_select ".markdown.content-page h1", count: 0
    assert_select "nav[aria-label='#{I18n.t("accessibility.active_admin.breadcrumb")}']",
      text: I18n.t("active_admin.site_header.handbook")
    assert_select "nav[aria-label='#{I18n.t("accessibility.active_admin.breadcrumb")}'] a", count: 0
  end
end
