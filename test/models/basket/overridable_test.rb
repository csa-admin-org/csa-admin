# frozen_string_literal: true

require "test_helper"

class Basket::OverridableTest < ActiveSupport::TestCase
  fixtures :all

  def setup
    Tenant.connect("acme")
  end

  def small_id; basket_sizes(:small).id; end
  def medium_id; basket_sizes(:medium).id; end
  def large_id; basket_sizes(:large).id; end
  def farm_id; depots(:farm).id; end
  def bakery_id; depots(:bakery).id; end
  def bread_id; basket_complements(:bread).id; end
  def eggs_id; basket_complements(:eggs).id; end

  test "basket edit creates override" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    basket = baskets(:jane_6)

    assert_difference "BasketOverride.count", 1 do
      basket.update!(depot_id: farm_id, depot_price: 0)
      basket.sync_basket_override!
    end

    override = BasketOverride.find_by(membership: membership, delivery: basket.delivery)
    assert_equal farm_id, override.diff["depot_id"]
    assert_equal 0.0, override.diff["depot_price"]
  end

  test "basket edit back to defaults destroys override" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    basket = baskets(:jane_6)

    # Create an override by changing depot
    basket.update!(depot_id: farm_id, depot_price: 0)
    basket.sync_basket_override!
    assert BasketOverride.exists?(membership: membership, delivery: basket.delivery)

    # Change back to membership defaults
    basket.update!(depot_id: bakery_id, depot_price: 4)
    basket.sync_basket_override!
    assert_not BasketOverride.exists?(membership: membership, delivery: basket.delivery)
  end

  test "partial basket edit stores only changed fields" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    basket = baskets(:john_6)

    basket.update!(quantity: 3)
    basket.sync_basket_override!

    override = BasketOverride.find_by(membership: membership, delivery: basket.delivery)
    assert_equal 3, override.diff["quantity"]
    assert_nil override.diff["depot_id"]
    assert_nil override.diff["basket_size_id"]
  end

  test "delivery swap creates override with override_delivery_id" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    basket = baskets(:john_6)
    original_delivery = basket.delivery
    target_delivery = deliveries(:monday_7)

    # Remove existing basket at target to allow the swap
    membership.baskets.find_by(delivery: target_delivery).destroy!

    basket.update!(delivery_id: target_delivery.id)
    basket.sync_basket_override!

    # Override should be keyed on the ORIGINAL delivery
    override = BasketOverride.find_by(membership: membership, delivery: original_delivery)
    assert_not_nil override
    assert_equal target_delivery.id, override.diff["override_delivery_id"]
  end

  test "delivery swap on basket with existing override captures both in diff" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    basket = baskets(:john_6)
    original_delivery = basket.delivery
    target_delivery = deliveries(:monday_7)

    # First, override the depot (creates a BasketOverride)
    basket.update!(depot_id: bakery_id, depot_price: 4)
    basket.sync_basket_override!
    override = BasketOverride.find_by(membership: membership, delivery: original_delivery)
    assert_not_nil override
    assert_equal bakery_id, override.diff["depot_id"]
    assert_nil override.diff["override_delivery_id"]

    # Now swap the delivery on top of the existing override
    membership.baskets.find_by(delivery: target_delivery).destroy!
    basket.reload.update!(delivery_id: target_delivery.id)
    basket.sync_basket_override!

    # The override should contain BOTH the depot change and the delivery swap
    override.reload
    assert_equal bakery_id, override.diff["depot_id"]
    assert_equal target_delivery.id, override.diff["override_delivery_id"]
  end

  test "complement edit creates override with complements in diff" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    basket = baskets(:jane_6)

    # Edit basket via nested attributes (like the admin form) to add eggs
    bbc = basket.baskets_basket_complements.first
    basket.update!(baskets_basket_complements_attributes: {
      "0" => { id: bbc.id, basket_complement_id: bbc.basket_complement_id, quantity: bbc.quantity, price: bbc.price },
      "1" => { basket_complement_id: eggs_id, quantity: 1, price: 6 }
    })
    basket.sync_basket_override!

    override = BasketOverride.find_by(membership: membership, delivery: basket.delivery)
    assert_not_nil override
    assert_not_nil override.diff["complements"]
  end
end
