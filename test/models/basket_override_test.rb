# frozen_string_literal: true

require "test_helper"

class BasketOverrideTest < ActiveSupport::TestCase
  def farm_id; depots(:farm).id; end
  def bakery_id; depots(:bakery).id; end
  def small_id; basket_sizes(:small).id; end
  def medium_id; basket_sizes(:medium).id; end
  def bread_id; basket_complements(:bread).id; end
  def eggs_id; basket_complements(:eggs).id; end

  test "compute_diff_from_basket returns nil when basket matches membership defaults" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    basket = baskets(:jane_6)

    diff = BasketOverride.compute_diff_from_basket(basket, membership)
    assert_nil diff
  end

  test "compute_diff_from_basket detects depot change" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    basket = baskets(:jane_6)
    basket.update!(depot_id: farm_id, depot_price: 0)

    diff = BasketOverride.compute_diff_from_basket(basket, membership)
    assert_not_nil diff
    assert_equal farm_id, diff["depot_id"]
    assert_equal 0.0, diff["depot_price"]
    assert_nil diff["basket_size_id"]
    assert_nil diff["quantity"]
  end

  test "compute_diff_from_basket detects complement change" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    basket = baskets(:jane_6)

    # Add eggs complement (jane only subscribes to bread)
    basket.baskets_basket_complements.create!(
      basket_complement_id: eggs_id, quantity: 2, price: 6)

    diff = BasketOverride.compute_diff_from_basket(basket.reload, membership)
    assert_not_nil diff
    assert_not_nil diff["complements"]
    assert_equal 2, diff["complements"].size
  end

  test "compute_diff_from_basket returns nil for shifted basket (quantities are shift-adjusted)" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    source = baskets(:jane_5)  # absent
    target = baskets(:jane_6)  # normal

    BasketShift.create!(
      absence: absences(:jane_thursday_5),
      membership: membership,
      source_delivery: source.delivery,
      target_delivery: target.delivery)

    # Target basket quantity is now 2 (1 original + 1 shifted)
    assert_equal 2, target.reload.quantity

    # But compute_diff should return nil because the quantity diff is from the shift
    diff = BasketOverride.compute_diff_from_basket(target, membership)
    assert_nil diff
  end

  test "apply_to! applies scalar overrides to a fresh basket" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    basket = baskets(:john_6)

    override = BasketOverride.create!(
      membership: membership,
      delivery: basket.delivery,
      diff: { "depot_id" => bakery_id, "depot_price" => 4 })

    # Simulate a fresh basket by resetting to config defaults
    basket.update_columns(depot_id: farm_id, depot_price: 0)
    basket.reload

    override.apply_to!(basket)
    assert_equal bakery_id, basket.reload.depot_id
    assert_equal 4, basket.depot_price
  end

  test "apply_to! applies complement overrides" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    basket = baskets(:jane_6)

    override = BasketOverride.create!(
      membership: membership,
      delivery: basket.delivery,
      diff: {
        "complements" => [
          { "basket_complement_id" => eggs_id, "quantity" => 2, "price" => 6.0 }
        ]
      })

    override.apply_to!(basket)
    basket.reload
    assert_equal [ eggs_id ], basket.baskets_basket_complements.map(&:basket_complement_id)
    assert_equal 2, basket.baskets_basket_complements.first.quantity
  end

  test "apply_to! handles delivery swap when target is free" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    basket = baskets(:john_6)
    target_delivery = deliveries(:monday_7)

    # Ensure no basket exists at the target delivery for this membership
    membership.baskets.where(delivery: target_delivery).destroy_all

    override = BasketOverride.create!(
      membership: membership,
      delivery: basket.delivery,
      diff: { "override_delivery_id" => target_delivery.id })

    override.apply_to!(basket)
    assert_equal target_delivery.id, basket.reload.delivery_id
  end

  test "apply_to! destroys occupying basket and moves on delivery swap" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    basket = baskets(:john_6)

    # Target delivery already has a (recreated) basket — this is the state
    # after config sync destroys + recreates baskets in the range.
    target_delivery = deliveries(:monday_7)
    occupying_basket = membership.baskets.find_by(delivery: target_delivery)
    assert_not_nil occupying_basket

    override = BasketOverride.create!(
      membership: membership,
      delivery: basket.delivery,
      diff: { "override_delivery_id" => target_delivery.id })

    override.apply_to!(basket)

    assert_equal target_delivery.id, basket.reload.delivery_id
    assert_not Basket.exists?(occupying_basket.id),
      "occupying basket should have been destroyed to make room for the swap"
  end

  test "apply_to! skips stale basket_size_id" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    basket = baskets(:john_6)

    override = BasketOverride.create!(
      membership: membership,
      delivery: basket.delivery,
      diff: {
        "basket_size_id" => 999999,  # Non-existent
        "depot_id" => bakery_id
      })

    override.apply_to!(basket)
    # basket_size_id unchanged (stale reference skipped), but depot applied
    assert_equal medium_id, basket.reload.basket_size_id
    assert_equal bakery_id, basket.depot_id
  end

  test "active? returns true when diff diverges from membership config" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    basket = baskets(:jane_6)

    # Override depot to farm (jane's config has bakery)
    override = BasketOverride.create!(
      membership: membership,
      delivery: basket.delivery,
      diff: { "depot_id" => farm_id, "depot_price" => 0.0 })

    assert override.active?
  end

  test "active? returns false when membership config matches the override (stale)" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    basket = baskets(:jane_6)

    # Override depot to bakery — which is already jane's membership config
    override = BasketOverride.create!(
      membership: membership,
      delivery: basket.delivery,
      diff: { "depot_id" => bakery_id, "depot_price" => 4.0 })

    assert_not override.active?
  end

  test "delivery_swap? returns true when diff contains override_delivery_id" do
    override = BasketOverride.new(
      diff: { "override_delivery_id" => 123 })

    assert override.delivery_swap?
  end

  test "delivery_swap? returns false when diff has no override_delivery_id" do
    override = BasketOverride.new(
      diff: { "depot_id" => farm_id })

    assert_not override.delivery_swap?
  end

  test "validation requires at least one override field" do
    membership = memberships(:john)
    delivery = deliveries(:monday_6)

    override = BasketOverride.new(
      membership: membership,
      delivery: delivery,
      diff: {})

    assert_not override.valid?
    assert override.errors[:base].any?
  end

  test "validation enforces uniqueness on membership_id + delivery_id" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    delivery = deliveries(:monday_6)

    BasketOverride.create!(
      membership: membership,
      delivery: delivery,
      diff: { "depot_id" => bakery_id })

    duplicate = BasketOverride.new(
      membership: membership,
      delivery: delivery,
      diff: { "quantity" => 2 })

    assert_not duplicate.valid?
    assert duplicate.errors[:delivery_id].any?
  end

  test "session is automatically set from Current.session on create" do
    travel_to "2024-01-01"
    session = sessions(:ultra)
    Current.session = session

    membership = memberships(:john)
    delivery = deliveries(:monday_6)

    override = BasketOverride.create!(
      membership: membership,
      delivery: delivery,
      diff: { "depot_id" => bakery_id })

    assert_equal session, override.session
    assert_equal session.owner, override.actor
  ensure
    Current.reset
  end

  test "destroy reverts basket to membership config defaults" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    basket = baskets(:jane_6)
    delivery = basket.delivery

    # Override depot to farm (jane's config has bakery)
    basket.update!(depot_id: farm_id, depot_price: 0)
    basket.sync_basket_override!
    override = BasketOverride.find_by(membership: membership, delivery: delivery)
    assert_not_nil override
    assert_equal farm_id, basket.reload.depot_id

    override.destroy!

    # Basket should be back to membership defaults (bakery)
    basket.reload
    assert_equal bakery_id, basket.depot_id
    assert_equal 4, basket.depot_price

    # Override should be destroyed
    assert_not BasketOverride.exists?(membership: membership, delivery: delivery)
  end

  test "destroy reverts complement overrides to membership subscription defaults" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    basket = baskets(:jane_6)
    delivery = basket.delivery

    # Add eggs directly on the basket (jane only subscribes to bread)
    basket.baskets_basket_complements.create!(
      basket_complement_id: eggs_id, quantity: 2, price: 6)

    # Create the override directly (complement join model changes don't trigger basket after_save)
    override = BasketOverride.create!(
      membership: membership,
      delivery: delivery,
      diff: {
        "complements" => basket.reload.baskets_basket_complements.sort_by(&:basket_complement_id).map { |bbc|
          { "basket_complement_id" => bbc.basket_complement_id, "quantity" => bbc.quantity, "price" => bbc.price.to_f }
        }
      })

    override.destroy!

    # Complements should be back to membership defaults (just bread)
    basket.reload
    complement_ids = basket.baskets_basket_complements.map(&:basket_complement_id)
    assert_not_includes complement_ids, eggs_id
    assert_not BasketOverride.exists?(membership: membership, delivery: delivery)
  end

  test "destroy moves delivery swap basket back to original delivery" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    basket = baskets(:john_6)
    original_delivery = basket.delivery
    target_delivery = deliveries(:monday_7)

    # Remove existing basket at target to allow the swap
    membership.baskets.find_by(delivery: target_delivery).destroy!
    basket.update!(delivery_id: target_delivery.id)
    basket.sync_basket_override!

    override = BasketOverride.find_by(membership: membership, delivery: original_delivery)
    assert_not_nil override
    assert override.delivery_swap?

    # Basket is at the swapped delivery
    assert membership.baskets.exists?(delivery: target_delivery)
    assert_not membership.baskets.exists?(delivery: original_delivery)

    override.destroy!

    # Basket should be back at the original delivery with config defaults
    assert membership.baskets.exists?(delivery: original_delivery)
    new_basket = membership.baskets.find_by(delivery: original_delivery)
    assert_equal membership.basket_size_id, new_basket.basket_size_id

    # Override should be destroyed
    assert_not BasketOverride.exists?(membership: membership, delivery: original_delivery)
  end

  test "destroy does not re-capture a new override" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    basket = baskets(:jane_6)
    delivery = basket.delivery

    basket.update!(depot_id: farm_id, depot_price: 0)
    basket.sync_basket_override!
    override = BasketOverride.find_by(membership: membership, delivery: delivery)

    assert_difference "BasketOverride.count", -1 do
      override.destroy!
    end
  end

  test "compute_diff_from_basket detects basket_size change" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    basket = baskets(:john_6)
    basket.update!(basket_size_id: small_id, basket_size_price: 10)

    diff = BasketOverride.compute_diff_from_basket(basket, membership)
    assert_not_nil diff
    assert_equal small_id, diff["basket_size_id"]
  end

  test "compute_diff_from_basket detects quantity change" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    basket = baskets(:john_6)
    basket.update!(quantity: 3)

    diff = BasketOverride.compute_diff_from_basket(basket, membership)
    assert_not_nil diff
    assert_equal 3, diff["quantity"]
  end

  test "apply_to! applies basket_size override" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    basket = baskets(:john_6)

    override = BasketOverride.create!(
      membership: membership,
      delivery: basket.delivery,
      diff: { "basket_size_id" => small_id })

    # Simulate a fresh basket by resetting to config defaults
    basket.update_columns(basket_size_id: medium_id, basket_size_price: 20)
    basket.reload

    override.apply_to!(basket)
    assert_equal small_id, basket.reload.basket_size_id
  end

  test "apply_to! applies quantity override" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    basket = baskets(:john_6)

    override = BasketOverride.create!(
      membership: membership,
      delivery: basket.delivery,
      diff: { "quantity" => 3 })

    basket.update_columns(quantity: 1)
    basket.reload

    override.apply_to!(basket)
    assert_equal 3, basket.reload.quantity
  end

  test "apply_to! self-destructs when all references are stale" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    basket = baskets(:john_6)

    override = BasketOverride.create!(
      membership: membership,
      delivery: basket.delivery,
      diff: { "basket_size_id" => 999999, "depot_id" => 999999 })

    override.apply_to!(basket)
    assert override.destroyed?
  end

  test "active? with complement diff" do
    travel_to "2024-01-01"
    membership = memberships(:jane)

    # Active: complement diff differs from expected (add eggs, jane only subscribes to bread)
    override_active = BasketOverride.create!(
      membership: membership,
      delivery: baskets(:jane_6).delivery,
      diff: {
        "complements" => [
          { "basket_complement_id" => eggs_id, "quantity" => 2, "price" => 6.0 }
        ]
      })
    assert override_active.active?

    # Stale: complement diff matches expected (jane subscribes to bread qty 1, price 4.0)
    override_stale = BasketOverride.create!(
      membership: membership,
      delivery: baskets(:jane_8).delivery,
      diff: {
        "complements" => [
          { "basket_complement_id" => bread_id, "quantity" => 1, "price" => 4.0 }
        ]
      })
    assert_not override_stale.active?
  end
end
