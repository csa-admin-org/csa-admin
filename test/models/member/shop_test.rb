# frozen_string_literal: true

require "test_helper"

class Member::ShopTest < ActiveSupport::TestCase
  test "validates shop_depot_id presence on public create in shop mode" do
    org(member_form_mode: "shop")
    member = build_member(public_create: true, shop_depot_id: nil)

    assert_not member.valid?
    assert_includes member.errors[:shop_depot_id], "can't be blank"

    member.shop_depot_id = depots(:farm).id
    assert member.valid?

    # Not required when no depots are visible
    Depot.update_all(visible: false)
    member.shop_depot_id = nil
    assert member.valid?
  end

  test "validates shop_depot_id not required on public create in membership mode" do
    member = build_member(public_create: true, waiting_basket_size_id: 0, shop_depot_id: nil)

    assert member.valid?
  end

  test "shop_delivery_cycle_id is optional when shop_depot_id is present" do
    member = build_member(shop_depot_id: depots(:farm).id, shop_delivery_cycle_id: nil)

    assert member.valid?
    assert_nil member.shop_delivery_cycle_id
  end

  test "clears shop_delivery_cycle_id when shop_depot_id is removed" do
    member = build_member(
      shop_depot_id: depots(:farm).id,
      shop_delivery_cycle_id: delivery_cycles(:mondays).id)

    member.shop_depot_id = nil
    member.valid?

    assert_nil member.shop_delivery_cycle_id
  end
end
