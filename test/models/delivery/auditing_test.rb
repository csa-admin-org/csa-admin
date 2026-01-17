# frozen_string_literal: true

require "test_helper"

class Delivery::AuditingTest < ActiveSupport::TestCase
  setup do
    # Travel to a date before the future fixtures to avoid validation errors
    travel_to "2025-01-01"
  end

  test "audits changes to date" do
    delivery = deliveries(:monday_future_1)
    original_date = delivery.date
    new_date = original_date + 1.day

    assert_difference(-> { Audit.where(auditable: delivery).count }, 1) do
      delivery.update!(date: new_date)
    end

    audit = delivery.audits.last
    assert_equal original_date.to_s, audit.audited_changes["date"].first
    assert_equal new_date.to_s, audit.audited_changes["date"].last
  end

  test "audits changes to note" do
    delivery = deliveries(:monday_future_1)

    assert_difference(-> { Audit.where(auditable: delivery).count }, 1) do
      delivery.update!(note: "Special delivery note")
    end

    audit = delivery.audits.last
    assert_equal [ nil, "Special delivery note" ], audit.audited_changes["note"]
  end

  test "audits changes to shop_open" do
    delivery = deliveries(:monday_future_1)
    delivery.update_columns(shop_open: true)

    assert_difference(-> { Audit.where(auditable: delivery).count }, 1) do
      delivery.update!(shop_open: false)
    end

    audit = delivery.audits.last
    assert_equal [ true, false ], audit.audited_changes["shop_open"]
  end

  test "audits changes to basket_size_price_percentage" do
    delivery = deliveries(:monday_future_1)

    assert_difference(-> { Audit.where(auditable: delivery).count }, 1) do
      delivery.update!(basket_size_price_percentage: 50)
    end

    audit = delivery.audits.last
    assert_nil audit.audited_changes["basket_size_price_percentage"].first
    assert_equal 50, audit.audited_changes["basket_size_price_percentage"].last.to_i
  end

  test "audits changes to shop_open_for_depot_ids when adding depots" do
    delivery = deliveries(:monday_future_1)
    farm = depots(:farm)
    bakery = depots(:bakery)

    # Start with no depots open (all closed)
    delivery.update_columns(shop_closed_for_depot_ids: Depot.pluck(:id))
    delivery.reload

    assert_difference(-> { Audit.where(auditable: delivery).count }, 1) do
      delivery.update!(shop_open_for_depot_ids: [ farm.id, bakery.id ])
    end

    audit = delivery.audits.last
    assert audit.audited_changes.key?("shop_open_for_depot_ids")
    changes = audit.audited_changes["shop_open_for_depot_ids"]
    assert_empty changes.first
    assert_equal [ farm.id, bakery.id ].sort, changes.last.sort
  end

  test "audits changes to shop_open_for_depot_ids when removing depots" do
    delivery = deliveries(:monday_future_1)
    farm = depots(:farm)
    bakery = depots(:bakery)
    home = depots(:home)

    # Start with all depots open
    delivery.update_columns(shop_closed_for_depot_ids: [])

    assert_difference(-> { Audit.where(auditable: delivery).count }, 1) do
      delivery.update!(shop_open_for_depot_ids: [ farm.id ])
    end

    audit = delivery.audits.last
    assert audit.audited_changes.key?("shop_open_for_depot_ids")
    changes = audit.audited_changes["shop_open_for_depot_ids"]
    assert_equal [ farm.id, bakery.id, home.id ].sort, changes.first.sort
    assert_equal [ farm.id ], changes.last
  end

  test "does not audit shop_open_for_depot_ids when unchanged" do
    delivery = deliveries(:monday_future_1)
    farm = depots(:farm)

    # Set initial state
    delivery.update_columns(shop_closed_for_depot_ids: Depot.where.not(id: farm.id).pluck(:id))

    assert_no_difference(-> { Audit.where(auditable: delivery).count }) do
      delivery.update!(shop_open_for_depot_ids: [ farm.id ])
    end
  end

  test "does not audit when no attribute changes" do
    delivery = deliveries(:monday_future_1)

    assert_no_difference(-> { Audit.where(auditable: delivery).count }) do
      delivery.save!
    end
  end

  test "combines multiple attribute changes into a single audit" do
    delivery = deliveries(:monday_future_1)
    delivery.update_columns(shop_open: true, shop_closed_for_depot_ids: Depot.pluck(:id))

    farm = depots(:farm)
    new_date = delivery.date + 1.day

    assert_difference(-> { Audit.where(auditable: delivery).count }, 1) do
      delivery.update!(
        date: new_date,
        note: "Combined changes",
        shop_open: false,
        shop_open_for_depot_ids: [ farm.id ]
      )
    end

    audit = delivery.audits.last
    assert audit.audited_changes.key?("date"), "Expected date in audited changes"
    assert audit.audited_changes.key?("note"), "Expected note in audited changes"
    assert audit.audited_changes.key?("shop_open"), "Expected shop_open in audited changes"
    assert audit.audited_changes.key?("shop_open_for_depot_ids"), "Expected shop_open_for_depot_ids in audited changes"
  end

  test "records session when auditing" do
    travel_to "2024-01-01"
    admin = admins(:super)
    session = create_session(admin)
    Current.session = session

    delivery = deliveries(:monday_future_1)

    assert_difference(-> { Audit.where(auditable: delivery).count }, 1) do
      delivery.update!(note: "Audited with session")
    end

    audit = delivery.audits.last
    assert_equal session, audit.session
    assert_equal admin, audit.actor
  end
end
