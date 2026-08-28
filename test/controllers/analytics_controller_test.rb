# frozen_string_literal: true

require "test_helper"

class AnalyticsControllerTest < ActionDispatch::IntegrationTest
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

  def headline_counter(title)
    css_select(".count").find { |count|
      count.css(".count-title").text == title
    }
  end

  def headline_values(title)
    JSON.parse(headline_counter(title).css("[data-analytics--headlines-target=value]").first["data-values"])
  end

  def chart_config
    JSON.parse(css_select("[data-analytics--chart-config-value]").first["data-analytics--chart-config-value"])
  end

  test "redirects to the memberships page" do
    travel_to "2025-01-15"
    login admins(:super)

    get analytics_path

    assert_redirected_to analytics_page_path(:memberships)
  end

  test "redirects unknown pages to memberships" do
    travel_to "2025-01-15"
    login admins(:super)

    get "/analytics/unknown"

    assert_redirected_to analytics_page_path(:memberships)
  end

  test "renders memberships page with hover-driven headlines" do
    travel_to "2025-01-15"
    login admins(:super)

    get analytics_page_path(:memberships)

    assert_response :success
    assert_select "h2", text: I18n.t("analytics.sections.memberships")
    assert_select "nav[aria-label='#{I18n.t("accessibility.active_admin.breadcrumb")}']",
      text: I18n.t("active_admin.site_header.analytics")
    assert_select "nav[aria-label='#{I18n.t("accessibility.active_admin.breadcrumb")}'] a", count: 0
    assert_select "[data-controller='analytics--headlines']"
    assert_select ".analytics-year[data-analytics--headlines-target=year]", text: "2024"
    assert_select ".count-title", text: I18n.t("analytics.metrics.memberships")
    assert_select ".count-title", text: I18n.t("analytics.metrics.new")
    assert_select ".count-title", text: I18n.t("analytics.metrics.renewal_rate")
    assert_select ".count-title", text: "#{I18n.t("analytics.metrics.average_price")} (CHF)"
    assert_select ".count-title", text: I18n.t("analytics.metrics.median_price"), count: 0
    assert_select "a[href='#memberships'][data-turbo='false']"
    assert_select "a[href='#trial-share']", count: 0
    assert_select "a[href='#renewal-outcome']", count: 0
    assert_select "a[href='#average-complements']", count: 0
    assert_select "[data-controller='analytics--chart']", minimum: 1
    assert_select "[data-analytics--chart-config-value]"
    assert_select "a[href='#price-extra-mix']", count: 0
    assert_select "a[href='#{analytics_page_path(:billing)}']"
    assert_select "a[href='#{analytics_page_path(:absences)}']"
    assert_select "a[href='#{analytics_page_path(:activities)}']"
    assert_select "a[href='#{analytics_page_path(:shop)}']", count: 0
    assert_select "a[href='#{analytics_page_path(:basket_content)}']", count: 0

    titles = css_select("#sidebar ul > li").map { |li| li.css("span").first.text.strip }
    assert_equal titles.sort_by { |title| I18n.transliterate(title) }, titles
  end

  test "renders billing page with hover-driven headlines" do
    travel_to "2025-01-15"
    login admins(:super)

    get analytics_page_path(:billing)

    assert_response :success
    assert_select "h2", text: I18n.t("analytics.sections.billing")
    assert_select "[data-controller='analytics--headlines']"
    assert_select ".count-title", text: "#{I18n.t("analytics.metrics.invoiced")} (CHF)"
    assert_select ".count-title", text: "#{I18n.t("billing.scope.paid")} (CHF)"
    assert_select ".count-title", text: I18n.t("analytics.metrics.time_to_pay_median")
    assert_select ".count-title", text: I18n.t("analytics.metrics.time_to_pay_p90")
    assert_select "a[href='#payments'][data-turbo='false']"
    assert_select "a[href='#invoice-share']", count: 0
    assert_select "a[href='#paid-rate']", count: 0
    assert_select "a[href='#open-remaining']", count: 0
    assert_select ".count-title", text: I18n.t("analytics.metrics.memberships"), count: 0
    assert_select "[data-controller='analytics--chart']", minimum: 1
    assert_select "[data-analytics--chart-config-value]"
  end

  test "keeps renewal closed-only and serializes YTD time to pay" do
    travel_to "2025-01-15"
    invoice = create_other_invoice(
      member: members(:jane),
      date: Date.new(2025, 1, 2),
      sent_at: Time.zone.parse("2025-01-02 09:00"),
      amount: 40)
    create_payment(
      member: members(:jane),
      invoice: invoice,
      amount: 40,
      date: Date.new(2025, 1, 10))
    login admins(:super)

    get analytics_page_path(:memberships)
    renewal_values = headline_values(I18n.t("analytics.metrics.renewal_rate"))
    assert_nil renewal_values.last

    get analytics_page_path(:billing)
    time_to_pay_values = headline_values(I18n.t("analytics.metrics.time_to_pay_median"))
    assert_equal I18n.t("analytics.metrics.days", count: 8), time_to_pay_values.last

    assert_select "[data-analytics--headlines-years-value*='(#{I18n.t("analytics.in_progress")})']"

    config = chart_config
    labels = config.dig("data", "labels")
    assert_equal labels.length - 1, config.dig("options", "openYearIndex")
    assert_equal "2025", labels.last
  end

  test "shows extra mix when membership extras differ" do
    travel_to "2025-01-15"
    memberships(:john).update_column(:basket_price_extra, 1)
    login admins(:super)

    get analytics_page_path(:memberships)

    assert_response :success
    assert_select "a[href='#price-extra-mix'][data-turbo='false']"
  end

  test "redirects to billing when there are no memberships" do
    travel_to "2025-01-15"
    login admins(:super)

    Membership.stub(:exists?, false) do
      get analytics_path

      assert_redirected_to analytics_page_path(:billing)
    end
  end

  test "hides memberships from the sidebar when there are none" do
    travel_to "2025-01-15"
    login admins(:super)

    Membership.stub(:exists?, false) do
      get analytics_page_path(:billing)

      assert_response :success
      assert_select "a[href='#{analytics_page_path(:memberships)}']", count: 0
      assert_select "a[href='#{analytics_page_path(:absences)}']"
      assert_select "a[href='#{analytics_page_path(:activities)}']"
    end
  end

  test "renders absences page" do
    travel_to "2025-01-15"
    login admins(:super)

    get analytics_page_path(:absences)

    assert_response :success
    assert_select "h2", text: I18n.t("analytics.sections.absences")
    assert_select ".count-title", text: I18n.t("analytics.metrics.absences")
    assert_select ".count-title", text: I18n.t("analytics.metrics.absent_members")
    assert_select ".count-title", text: I18n.t("analytics.metrics.absent_baskets")
    assert_select ".count-title", text: I18n.t("analytics.metrics.absent_basket_rate")
    assert_select "a[href='#absences'][data-turbo='false']"
    assert_select "a[href='#absent-basket-rate'][data-turbo='false']"
    assert_select "a[href='#included-quota']", count: 0
    assert_select "a[href='#announcement-delay'][data-turbo='false']"
  end

  test "renders included quota mix when a membership has unused leftover" do
    travel_to "2025-01-15"
    memberships(:john).update!(absences_included_annually: 1)
    login admins(:super)

    get analytics_page_path(:absences)

    assert_response :success
    assert_select "a[href='#included-quota'][data-turbo='false']"
  end

  test "renders activities page" do
    travel_to "2025-01-15"
    login admins(:super)

    get analytics_page_path(:activities)

    assert_response :success
    assert_select "h2", text: activities_human_name
    assert_select ".count-title", text: I18n.t("analytics.metrics.demanded")
    assert_select ".count-title", text: I18n.t("analytics.metrics.accepted")
    assert_select ".count-title", text: I18n.t("analytics.metrics.fulfillment_rate")
    assert_select ".count-title", text: I18n.t("analytics.metrics.billed_missing")
    assert_select "a[href='#demanded-accepted'][data-turbo='false']"
    assert_select "a[href='#accepted-mix']", count: 0
    billed_missing = headline_counter(I18n.t("analytics.metrics.billed_missing")).css(".count-value").first
    assert_equal "0", billed_missing.text
    assert_not billed_missing["class"].include?("count-zero")
  end

  test "renders shop page after an order is invoiced" do
    travel_to "2025-01-15"
    create_shop_order.invoice!
    login admins(:super)

    get analytics_page_path(:shop)

    assert_response :success
    assert_select "h2", text: I18n.t("analytics.sections.shop")
    assert_select ".count-title", text: "#{I18n.t("analytics.metrics.delivered")} (CHF)"
    assert_select ".count-title", text: I18n.t("analytics.metrics.shop_orders")
    assert_select ".count-title", text: I18n.t("analytics.metrics.shop_members")
    assert_select ".count-title", text: "#{I18n.t("analytics.metrics.average_order")} (CHF)"
    assert_select "a[href='#shop-amounts'][data-turbo='false']"
    assert_select "a[href='#shop-orders'][data-turbo='false']"
    assert_select "a[href='#shop-average'][data-turbo='false']"
    assert_select "a[href='#shop-products']", count: 0
  end

  test "renders basket content page after a delivery is filled" do
    travel_to "2025-01-15"
    create_basket_content(unit: "pc", unit_price: 2)
    login admins(:super)

    get analytics_page_path(:basket_content)

    assert_response :success
    assert_select "h2", text: I18n.t("analytics.sections.basket_content")
    assert_select ".count-title", text: I18n.t("analytics.metrics.filled_deliveries")
    assert_select ".count-title", text: I18n.t("analytics.metrics.coverage_rate")
    assert_select ".count-title", text: I18n.t("analytics.metrics.products")
    assert_select ".count-title", text: "#{I18n.t("analytics.metrics.median_content_value")} (CHF)"
    assert_select "a[href='#filled-deliveries'][data-turbo='false']"
    assert_select "a[href='#top-products']", count: 0
    assert_select "a[href='#content-value'][data-turbo='false']"
    assert_select "a[href='#content-price-gap'][data-turbo='false']"
  end

  test "header includes the analytics icon for any admin" do
    travel_to "2025-01-15"
    login admins(:external)

    get memberships_path

    assert_response :success
    assert_select "a[href='#{analytics_path}'][title='#{I18n.t("active_admin.site_header.analytics")}'][data-turbo-prefetch=false]"
    assert_select "a[href='#{support_path}'][title='#{I18n.t("active_admin.site_header.support")}'][data-turbo-prefetch=false]"
  end
end
