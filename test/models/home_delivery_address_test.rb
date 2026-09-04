# frozen_string_literal: true

require "test_helper"

class HomeDeliveryAddressTest < ActiveSupport::TestCase
  setup do
    travel_to "2024-04-01"
    @member = members(:bob)
    @delivery = deliveries(:monday_1)
  end

  test "creates overlay for home delivery basket" do
    overlay = HomeDeliveryAddress.new(
      member: @member,
      name: "Valentine Schneider",
      street: "Chantemerle 16",
      zip: "2000",
      city: "Neuchatel",
      deliveries: [ @delivery ])

    assert overlay.valid?
    assert overlay.save!
    assert_equal @member.id, overlay.home_delivery_address_deliveries.first.member_id
  end

  test "requires name and address" do
    overlay = HomeDeliveryAddress.new(member: @member, deliveries: [ @delivery ])

    assert_not overlay.valid?
    assert overlay.errors[:name].any?
    assert overlay.errors[:street].any?
    assert overlay.errors[:zip].any?
    assert overlay.errors[:city].any?
  end

  test "member-managed overlay requires at least one delivery" do
    overlay = HomeDeliveryAddress.new(
      member: @member,
      name: "Valentine Schneider",
      street: "Chantemerle 16",
      zip: "2000",
      city: "Neuchatel",
      member_managed: true)

    assert_not overlay.valid?
    assert overlay.errors[:delivery_ids].any?
  end

  test "admin overlay can have no deliveries" do
    overlay = HomeDeliveryAddress.new(
      member: @member,
      name: "Valentine Schneider",
      street: "Chantemerle 16",
      zip: "2000",
      city: "Neuchatel")

    assert overlay.valid?
    assert overlay.save!
    assert_empty overlay.delivery_ids
  end

  test "rejects signature depot deliveries" do
    overlay = HomeDeliveryAddress.new(
      member: members(:john),
      name: "Valentine Schneider",
      street: "Chantemerle 16",
      zip: "2000",
      city: "Neuchatel",
      deliveries: [ deliveries(:monday_1) ])

    assert_not overlay.valid?
    assert_includes overlay.errors[:delivery_ids], I18n.t("activerecord.errors.models.home_delivery_address.attributes.delivery_ids.not_eligible")
  end

  test "rejects absent baskets" do
    basket = baskets(:bob_1)
    basket.update_column(:state, "absent")

    overlay = HomeDeliveryAddress.new(
      member: @member,
      name: "Valentine Schneider",
      street: "Chantemerle 16",
      zip: "2000",
      city: "Neuchatel",
      deliveries: [ @delivery ])

    assert_not overlay.valid?
    assert overlay.errors[:delivery_ids].any?
  end

  test "taken_delivery_ids_for excludes the current overlay" do
    overlay = HomeDeliveryAddress.create!(
      member: @member,
      name: "Valentine Schneider",
      street: "Chantemerle 16",
      zip: "2000",
      city: "Neuchatel",
      deliveries: [ @delivery ])

    assert_equal [ @delivery.id ], HomeDeliveryAddress.taken_delivery_ids_for(@member)
    assert_empty HomeDeliveryAddress.taken_delivery_ids_for(@member, except: overlay)
  end

  test "prevents two overlays for the same member and delivery" do
    HomeDeliveryAddress.create!(
      member: @member,
      name: "Valentine Schneider",
      street: "Chantemerle 16",
      zip: "2000",
      city: "Neuchatel",
      deliveries: [ @delivery ])

    duplicate = HomeDeliveryAddress.new(
      member: @member,
      name: "Someone Else",
      street: "Elsewhere 1",
      zip: "2000",
      city: "Neuchatel",
      deliveries: [ @delivery ])
    assert_not duplicate.valid?

    other = HomeDeliveryAddress.new(
      member: @member,
      name: "Someone Else",
      street: "Elsewhere 1",
      zip: "2000",
      city: "Neuchatel")
    other.save(validate: false)
    assert_raises(ActiveRecord::RecordNotUnique) do
      HomeDeliveryAddressDelivery.insert_all!([
        {
          home_delivery_address_id: other.id,
          delivery_id: @delivery.id,
          member_id: @member.id,
          created_at: Time.current,
          updated_at: Time.current
        }
      ])
    end
  end

  test "for returns overlay when basket depot is home delivery" do
    overlay = HomeDeliveryAddress.create!(
      member: @member,
      name: "Valentine Schneider",
      street: "Chantemerle 16",
      zip: "2000",
      city: "Neuchatel",
      deliveries: [ @delivery ])

    assert_equal overlay, HomeDeliveryAddress.for(@member, @delivery)
  end

  test "for returns nil after depot switch" do
    HomeDeliveryAddress.create!(
      member: @member,
      name: "Valentine Schneider",
      street: "Chantemerle 16",
      zip: "2000",
      city: "Neuchatel",
      deliveries: [ @delivery ])

    baskets(:bob_1).update_columns(depot_id: depots(:farm).id)

    assert_nil HomeDeliveryAddress.for(@member.reload, @delivery)
  end

  test "next_delivery_date is the soonest coming delivery" do
    overlay = HomeDeliveryAddress.create!(
      member: @member,
      name: "Valentine Schneider",
      street: "Chantemerle 16",
      zip: "2000",
      city: "Neuchatel",
      deliveries: [ @delivery ])

    assert_equal @delivery.date, overlay.next_delivery_date
  end

  test "sheet_note prefers overlay note" do
    @member.update_column(:delivery_note, "Code 1234")
    overlay = HomeDeliveryAddress.new(member: @member, note: "Leave at door")

    assert_equal "Leave at door", overlay.sheet_note
  end

  test "sheet_note falls back to member delivery_note" do
    @member.update_column(:delivery_note, "Code 1234")
    overlay = HomeDeliveryAddress.new(member: @member, note: nil)

    assert_equal "Code 1234", overlay.sheet_note
  end

  test "sheet_address uses the host name without a prefix" do
    overlay = HomeDeliveryAddress.new(
      name: "Valentine Schneider",
      street: "Chantemerle 16",
      zip: "2000",
      city: "Neuchatel")

    assert_equal "Valentine Schneider\nChantemerle 16\n2000 Neuchatel", overlay.sheet_address
  end

  test "eligible_baskets_for keeps already attached absent deliveries" do
    overlay = HomeDeliveryAddress.create!(
      member: @member,
      name: "Valentine Schneider",
      street: "Chantemerle 16",
      zip: "2000",
      city: "Neuchatel",
      deliveries: [ @delivery ])
    baskets(:bob_1).update_column(:state, "absent")

    eligible_ids = HomeDeliveryAddress.eligible_baskets_for(@member, keep_delivery_ids: overlay.delivery_ids).map(&:delivery_id)

    assert_includes eligible_ids, @delivery.id
    overlay.delivery_ids = [ @delivery.id ]
    assert overlay.valid?
  end

  test "anonymize clears overlay PII" do
    overlay = HomeDeliveryAddress.create!(
      member: @member,
      name: "Valentine Schneider",
      street: "Chantemerle 16",
      zip: "2000",
      city: "Neuchatel",
      note: "Leave at door",
      deliveries: [ @delivery ])

    @member.send(:anonymize_home_delivery_addresses!)

    overlay.reload
    assert_equal "DELETED", overlay.name
    assert_nil overlay.street
    assert_nil overlay.zip
    assert_nil overlay.city
    assert_nil overlay.note
  end

  test "can_member_create_for? is true for coming home-delivery baskets" do
    assert HomeDeliveryAddress.can_member_create_for?(baskets(:bob_1))
    assert_not HomeDeliveryAddress.can_member_create_for?(memberships(:john).baskets.first)
  end

  test "member_managed overlay cannot drop frozen dates" do
    overlay = HomeDeliveryAddress.create!(
      member: @member,
      name: "Valentine Schneider",
      street: "Chantemerle 16",
      zip: "2000",
      city: "Neuchatel",
      deliveries: [ @delivery ])
    overlay.member_managed = true
    org(basket_update_limit_in_days: 30)

    overlay.delivery_ids = []
    assert overlay.valid?
    assert_includes overlay.delivery_ids.map(&:to_i), @delivery.id
  end

  test "admin update keeps past deliveries omitted from params" do
    overlay = HomeDeliveryAddress.create!(
      member: @member,
      name: "Valentine Schneider",
      street: "Chantemerle 16",
      zip: "2000",
      city: "Neuchatel",
      deliveries: [ @delivery ])
    HomeDeliveryAddressDelivery.insert_all!([
      {
        home_delivery_address_id: overlay.id,
        delivery_id: deliveries(:monday_past_1).id,
        member_id: @member.id,
        created_at: Time.current,
        updated_at: Time.current
      }
    ])
    overlay.reload
    overlay.delivery_ids = [ @delivery.id ]

    assert overlay.valid?
    overlay.save!
    assert_includes overlay.reload.delivery_ids, deliveries(:monday_past_1).id
  end

  test "member_managed overlay cannot change address while frozen dates remain" do
    overlay = HomeDeliveryAddress.create!(
      member: @member,
      name: "Valentine Schneider",
      street: "Chantemerle 16",
      zip: "2000",
      city: "Neuchatel",
      deliveries: [ @delivery ])
    overlay.member_managed = true
    org(basket_update_limit_in_days: 30)

    overlay.name = "Alice Doe"

    assert_not overlay.valid?
    assert overlay.errors[:base].any?
    assert_equal "Valentine Schneider", overlay.reload.name
  end

  test "destroying a session nullifies overlay session_id" do
    overlay = HomeDeliveryAddress.create!(
      member: @member,
      name: "Valentine Schneider",
      street: "Chantemerle 16",
      zip: "2000",
      city: "Neuchatel",
      deliveries: [ @delivery ],
      session: sessions(:john))

    sessions(:john).destroy!

    assert_nil overlay.reload.session_id
  end

  test "can_member_destroy? is false when frozen dates remain" do
    overlay = HomeDeliveryAddress.create!(
      member: @member,
      name: "Valentine Schneider",
      street: "Chantemerle 16",
      zip: "2000",
      city: "Neuchatel",
      deliveries: [ @delivery ])
    HomeDeliveryAddressDelivery.insert_all!([
      {
        home_delivery_address_id: overlay.id,
        delivery_id: deliveries(:monday_past_1).id,
        member_id: @member.id,
        created_at: Time.current,
        updated_at: Time.current
      }
    ])
    overlay.reload

    assert overlay.can_member_update?
    assert_not overlay.can_member_destroy?
  end
end
