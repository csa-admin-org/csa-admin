# frozen_string_literal: true

require "test_helper"

class Members::ForcedDeliveriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "members.acme.test"
    org(features: [ :absence ], absence_notice_period_in_days: 7)
  end

  def login(member)
    session = Session.create!(
      member: member,
      email: member.emails_array.first,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    # Redeem the session token to set the encrypted cookie
    get "/sessions/#{session.generate_token_for(:redeem)}"
  end

  test "create forces a provisionally absent basket" do
    membership = memberships(:jane)
    membership.update_column(:absences_included_reminder_sent_at, Time.current)
    basket = baskets(:jane_10)
    basket.update_columns(state: "absent", absence_id: nil, billable: false)

    login(members(:jane))
    travel_to basket.delivery.date - 14.days

    assert_difference "ForcedDelivery.count", 1 do
      post members_basket_forced_delivery_path(basket)
    end

    assert_redirected_to members_deliveries_path
    assert_equal I18n.t("members.forced_deliveries.create.flash.notice"), flash[:notice]

    forced_delivery = ForcedDelivery.last
    assert_equal membership, forced_delivery.membership
    assert_equal basket.delivery, forced_delivery.delivery
  end

  test "create redirects with alert when basket cannot be forced" do
    membership = memberships(:jane)
    membership.update_column(:absences_included_reminder_sent_at, nil) # Reminder not sent
    basket = baskets(:jane_10)
    basket.update_columns(state: "absent", absence_id: nil, billable: false)

    login(members(:jane))
    travel_to basket.delivery.date - 14.days

    assert_no_difference "ForcedDelivery.count" do
      post members_basket_forced_delivery_path(basket)
    end

    assert_redirected_to members_deliveries_path
    assert_equal I18n.t("members.forced_deliveries.create.flash.alert"), flash[:alert]
  end

  test "create requires authentication" do
    basket = baskets(:jane_10)

    post members_basket_forced_delivery_path(basket)

    assert_redirected_to members_login_path
  end

  test "create cannot force another member's basket" do
    basket = baskets(:jane_10)

    login(members(:john)) # Different member
    travel_to basket.delivery.date - 14.days

    assert_no_difference "ForcedDelivery.count" do
      post members_basket_forced_delivery_path(basket)
    end

    # Should get 404 since John can't access Jane's basket
    assert_response :not_found
  end
end
