# frozen_string_literal: true

require "test_helper"

class Delivery::BasketSummarySectionsTest < ActiveSupport::TestCase
  test "returns price section when no depot groups are used" do
    sections = Delivery::BasketSummarySections.new(deliveries(:monday_1)).sections

    assert_equal [ :price ], sections.map(&:dimension)
    assert_equal [ I18n.t("delivery.free_depots"), I18n.t("delivery.paid_depots") ], sections.first.rows.map(&:title)
    assert_equal [ [ farm_id ], [ home_id, bakery_id ] ], sections.first.rows.map(&:depot_ids)
  end

  test "keeps depot-group and price sections when they partition depots differently" do
    countryside = DepotGroup.create!(
      names: { en: "Countryside route" },
      public_names: { en: "Public countryside route" },
      member_order_priority: 2)
    city = DepotGroup.create!(
      names: { en: "City route" },
      public_names: { en: "Public city route" },
      member_order_priority: 1)

    depots(:farm).update!(group: countryside)
    depots(:home).update!(group: countryside)
    depots(:bakery).update!(group: city)

    sections = Delivery::BasketSummarySections.new(deliveries(:monday_1)).sections

    assert_equal [ :depot_group, :price ], sections.map(&:dimension)
    assert_equal [ "City route", "Countryside route" ], sections.first.rows.map(&:title)
    assert_equal [ [ bakery_id ], [ farm_id, home_id ] ], sections.first.rows.map(&:depot_ids)
    assert_equal [ I18n.t("delivery.free_depots"), I18n.t("delivery.paid_depots") ], sections.second.rows.map(&:title)
    assert_equal [ [ farm_id ], [ home_id, bakery_id ] ], sections.second.rows.map(&:depot_ids)
  end

  test "suppresses price section when depot groups already match the free and paid split" do
    free_route = DepotGroup.create!(
      names: { en: "Free route" },
      public_names: { en: "Free route" })
    paid_route = DepotGroup.create!(
      names: { en: "Paid route" },
      public_names: { en: "Paid route" })

    depots(:farm).update!(group: free_route)
    depots(:home).update!(group: paid_route)
    depots(:bakery).update!(group: paid_route)

    sections = Delivery::BasketSummarySections.new(deliveries(:monday_1)).sections

    assert_equal [ :depot_group ], sections.map(&:dimension)
    assert_equal [ "Free route", "Paid route" ], sections.first.rows.map(&:title)
    assert_equal [ [ farm_id ], [ home_id, bakery_id ] ], sections.first.rows.map(&:depot_ids)
  end

  test "suppresses depot-group section when all used depots belong to the same group" do
    route = DepotGroup.create!(
      names: { en: "Route" },
      public_names: { en: "Public route" })

    depots(:farm).update!(group: route)
    depots(:home).update!(group: route)
    depots(:bakery).update!(group: route)

    sections = Delivery::BasketSummarySections.new(deliveries(:monday_1)).sections

    assert_equal [ :price ], sections.map(&:dimension)
  end

  test "adds an ungrouped depots row when grouped and ungrouped depots coexist" do
    route = DepotGroup.create!(
      names: { en: "Route" },
      public_names: { en: "Route" })

    depots(:farm).update!(group: route)

    sections = Delivery::BasketSummarySections.new(deliveries(:monday_1)).sections

    assert_equal [ :depot_group ], sections.map(&:dimension)
    assert_equal [ "Route", I18n.t("delivery.ungrouped_depots") ], sections.first.rows.map(&:title)
    assert_equal [ [ farm_id ], [ home_id, bakery_id ] ], sections.first.rows.map(&:depot_ids)
  end
end
