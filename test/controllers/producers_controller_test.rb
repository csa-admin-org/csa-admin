# frozen_string_literal: true

require "test_helper"

class ProducersControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "admin.acme.test"
    login admins(:super)
  end

  test "index explains what producers are for" do
    get producers_path

    assert_response :success
    assert_select ".admin-side-panel", text: /#{Regexp.escape(I18n.t("active_admin.shared.sidebar_section.producer_info"))}/
    assert_select "a[href='/handbook/shop#producers']"
  end

  test "index shows only the enabled feature columns" do
    org(features: [ :shop ])

    get producers_path

    assert_response :success
    assert_select "th", text: I18n.t("shop.title")
    assert_select "th", text: BasketContent.model_name.human, count: 0

    org(features: [ :basket_content ])

    get producers_path

    assert_response :success
    assert_select "th", text: BasketContent.model_name.human
    assert_select "th", text: I18n.t("shop.title"), count: 0
  end

  test "menu hides producers when shop and basket content are off" do
    org(features: [])

    get root_path

    assert_response :success
    assert_select "a[href='#{producers_path}']", count: 0

    get producers_path

    assert_redirected_to root_path
  end

  private

  def login(admin)
    session = Session.create!(
      admin_email: admin.email,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
  end
end
