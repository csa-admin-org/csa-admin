# frozen_string_literal: true

require "test_helper"

class Members::BasketShiftsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "members.acme.test"
    travel_to "2024-01-01"
    org(
      features: [ :absence ],
      absences_billed: true,
      basket_shifts_annually: 1,
      basket_shift_deadline_in_weeks: nil)
    login(members(:jane))
  end

  test "new redirects when basket cannot be shifted" do
    basket = baskets(:jane_6)

    get new_members_basket_basket_shifts_path(basket)

    assert_redirected_to members_deliveries_path
    assert_equal I18n.t("members.basket_shifts.flash.alert"), flash[:alert]
  end

  test "create cannot decline shift for ineligible basket" do
    basket = baskets(:jane_6)

    assert_no_changes -> { basket.reload.shift_declined_at } do
      post members_basket_basket_shifts_path(basket), params: {
        basket: { shift_target_basket_id: "declined" }
      }
    end

    assert_redirected_to members_deliveries_path
    assert_equal I18n.t("members.basket_shifts.flash.alert"), flash[:alert]
  end

  private

  def login(member)
    session = Session.create!(
      member: member,
      email: member.emails_array.first,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
  end
end
