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

  test "members handbook does not claim an XLSX export" do
    admin = admins(:super)
    login admin

    I18n.available_locales.each do |locale|
      admin.update!(language: locale.to_s)

      get handbook_page_path(:members)

      assert_response :success
      assert_not_includes response.body, "XLSX"
      assert_includes response.body, "CSV"
    end
  end

  test "activity handbook form section uses the tenant participation price" do
    admin = admins(:super)
    login admin
    org(activity_price: 75, currency_code: "CHF")

    I18n.available_locales.each do |locale|
      admin.update!(language: locale.to_s)

      get handbook_page_path(:activity)

      assert_response :success
      assert_select "a[href='/basket_sizes']"
      assert_select "a[href='/settings#activity']"
      assert_select "a[href='/activity_participations']"
      assert_select "a[href='#activity-participations-logic']"
      assert_select "a[href='/support']"
      assert_includes response.body, "CHF\u00A075"
      assert_includes response.body, "CHF\u00A0150"
      assert_not_includes response.body, "&lt;%"
    end

    org(activity_price: 0)
    admin.update!(language: "en")

    get handbook_page_path(:activity)

    assert_response :success
    assert_not_includes response.body, "CHF"
    assert_includes response.body, "does not change the membership price"
    assert_select "a[href='/basket_sizes']"
  end

  test "price reductions handbook renders in every locale" do
    admin = admins(:super)
    login admin

    I18n.available_locales.each do |locale|
      admin.update!(language: locale.to_s)

      get handbook_page_path(:price_reductions)

      assert_response :success
      assert_select "h2", text: I18n.t("features.price_reductions", locale: locale)
      assert_select "a[href='/handbook/basket_price_extra']"
    end
  end
end
