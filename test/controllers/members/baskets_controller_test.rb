# frozen_string_literal: true

require "test_helper"

class Members::BasketsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "members.acme.test"
    travel_to "2024-01-01"
    org(
      membership_depot_update_allowed: true,
      membership_complements_update_allowed: true,
      basket_update_limit_in_days: 5)
  end

  def login(member)
    session = Session.create!(
      member: member,
      email: member.emails_array.first,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
  end

  test "update redirects when no complements and single depot" do
    org(
      membership_depot_update_allowed: true,
      membership_complements_update_allowed: true)

    basket = memberships(:jane).baskets.first
    # Remove all complements from the delivery
    basket.delivery.basket_complements.clear
    # Hide all depots except the current one
    Depot.where.not(id: basket.depot_id).update_all(visible: false)

    login(members(:jane))

    # The basket should no longer be editable
    assert_not basket.can_member_update?

    get edit_members_basket_path(basket)
    assert_redirected_to members_deliveries_path

    patch members_basket_path(basket)
    assert_redirected_to members_deliveries_path
  end

  test "update depot" do
    basket = memberships(:jane).baskets.first

    login(members(:jane))

    assert_changes -> { basket.reload.depot_id }, to: home_id do
      patch members_basket_path(basket), params: {
        basket: { depot_id: home_id }
      }
    end

    assert_redirected_to members_deliveries_path
  end

  test "update requires authentication" do
    basket = memberships(:jane).baskets.first

    patch members_basket_path(basket)

    assert_redirected_to members_login_path
  end

  test "update cannot access another member's basket" do
    basket = memberships(:jane).baskets.first

    login(members(:john))

    patch members_basket_path(basket), params: {
      basket: { depot_id: home_id }
    }

    assert_response :not_found
  end
end
