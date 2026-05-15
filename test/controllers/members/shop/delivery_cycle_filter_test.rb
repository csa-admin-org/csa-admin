# frozen_string_literal: true

require "test_helper"

class Members::Shop::DeliveryCycleFilterTest < ActionDispatch::IntegrationTest
  include ShopHelper

  setup do
    host! "members.acme.test"
    travel_to "2024-04-01"
    org(features: %w[shop])
    # Close all deliveries by default, open specific ones per test
    Delivery.update_all(shop_open: false)
  end

  def login(member)
    session = Session.create!(
      member: member,
      email: member.emails_array.first,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
  end

  test "shop depot member without delivery cycle sees all open deliveries" do
    member = members(:martha)
    member.update!(shop_depot_id: farm_id)

    deliveries(:monday_2).update!(shop_open: true) # 2024-04-08
    deliveries(:thursday_1).update!(shop_open: true) # 2024-04-04

    login(member)

    get members_shop_path
    assert_response :success
    # Thursday is the first open coming delivery
    assert_match "Thursday 4 April 2024", response.body
  end

  test "shop depot member with delivery cycle only sees matching deliveries" do
    member = members(:martha)
    member.update!(
      shop_depot_id: farm_id,
      shop_delivery_cycle: delivery_cycles(:thursdays))

    # Open both Monday and Thursday deliveries
    deliveries(:monday_2).update!(shop_open: true) # 2024-04-08
    deliveries(:thursday_1).update!(shop_open: true) # 2024-04-04

    login(member)

    get members_shop_path
    assert_response :success
    # Only Thursday is visible (Monday is filtered out by Thursdays cycle)
    assert_match "Thursday 4 April 2024", response.body
    assert_no_match(/Monday 8 April 2024/, response.body)
  end

  test "shop depot member with delivery cycle that excludes all open deliveries sees no shop" do
    member = members(:martha)
    member.update!(
      shop_depot_id: farm_id,
      shop_delivery_cycle: delivery_cycles(:mondays))

    # Only open Thursday delivery (excluded by Mondays cycle)
    deliveries(:thursday_1).update!(shop_open: true)

    login(member)

    get members_shop_path
    # No deliveries match: Mondays cycle doesn't include Thursday
    assert_redirected_to members_member_path
  end

  private

  def farm_id
    depots(:farm).id
  end
end
