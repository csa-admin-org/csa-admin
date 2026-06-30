# frozen_string_literal: true

require "test_helper"

class DepotTest < ActiveSupport::TestCase
  def member_ordered_names
    Depot.member_ordered.map(&:name)
  end

  test "member_ordered" do
    assert_equal %w[ Farm Bakery Home ], member_ordered_names

    org(depots_member_order_mode: "price_desc")
    assert_equal %w[ Home Bakery Farm], member_ordered_names

    org(depots_member_order_mode: "name_asc")
    assert_equal %w[ Bakery Home Farm ], member_ordered_names

    depots(:bakery).update!(member_order_priority: 2)
    assert_equal %w[ Home Farm Bakery], member_ordered_names
  end

  test "deliveries_count counts future deliveries when exists" do
    travel_to "2024-07-01"
    depot = depots(:farm)
    assert_changes -> { depot.reload.billable_deliveries_counts }, from: [ 10, 20 ], to: [ 10, 11, 21 ] do
      Delivery.create!(date: deliveries(:monday_future_10).date + 1.week)
    end
  end

  test "move_to moves depot to a new position" do
    travel_to "2024-01-01"
    d1 = depots(:farm)
    d2 = depots(:home)
    d3 = depots(:bakery)
    memberships(:bob).destroy!

    assert_changes -> { Depot.pluck(:id) }, from: [ d1.id, d2.id, d3.id ], to: [ d2.id, d3.id, d1.id ] do
      d1.move_to(2, deliveries(:monday_1))
    end
  end

  test "move_to moves depot to a new position with delivery context respected" do
    travel_to "2024-01-01"
    d1 = depots(:farm)
    d2 = depots(:home)
    d3 = depots(:bakery)

    assert_changes -> { Depot.pluck(:id) }, from: [ d1.id, d2.id, d3.id ], to: [ d2.id, d1.id, d3.id ] do
      d1.move_to(2, deliveries(:monday_1))
    end
  end

  def depot_member_names(depot, delivery)
    depot.baskets_for(delivery).map(&:member).map(&:name)
  end

  test "move_member_to moves member to a new position" do
    travel_to "2024-01-01"
    depot = depots(:home)
    depot.update_column(:delivery_sheets_mode, "home_delivery")
    members(:john).update!(name: "John")
    members(:jane).update!(name: "Jane")
    members(:bob).update!(name: "Bob")
    memberships(:john).update!(depot: depot)
    memberships(:jane).update!(depot: depot, delivery_cycle: delivery_cycles(:mondays))

    assert_changes -> { depot_member_names(depot, deliveries(:monday_1)) }, from: %w[ Bob Jane John ], to: %w[ Bob John Jane ] do
      depot.move_member_to(2, members(:john), deliveries(:monday_1))
    end

    depot.update_column(:delivery_sheets_mode, "signature_sheets")
    assert_equal %w[ Bob Jane John ], depot_member_names(depot, deliveries(:monday_1))
  end

  test "move_member_to moves member to a new position with delivery context respected" do
    travel_to "2024-01-01"
    depot = depots(:home)
    depot.update_column(:delivery_sheets_mode, "home_delivery")
    members(:john).update!(name: "John")
    members(:jane).update!(name: "Jane")
    members(:bob).update!(name: "Bob")
    memberships(:john).update!(depot: depot)
    memberships(:jane).update!(depot: depot, delivery_cycle: delivery_cycles(:mondays))

    assert_changes -> { depot_member_names(depot, deliveries(:monday_1)) }, from: %w[ Bob Jane John ], to: %w[ John Bob Jane ] do
      depot.move_member_to(1, members(:john), deliveries(:monday_1))
    end

    assert_equal %w[ John Jane ], depot_member_names(depot, deliveries(:monday_2))
  end

  test "member_sorting sorts names case and accent insensitively" do
    travel_to "2024-01-01"
    depot = depots(:home)
    members(:john).update!(name: "Élodie")
    members(:jane).update!(name: "alice")
    members(:bob).update!(name: "Bob")
    memberships(:john).update!(depot: depot)
    memberships(:jane).update!(depot: depot, delivery_cycle: delivery_cycles(:mondays))

    assert_equal %w[ alice Bob Élodie ], depot_member_names(depot, deliveries(:monday_1))
  end

  test "invoice_description uses invoice_name when present" do
    depot = depots(:bakery)
    depot.update!(invoice_names: { "en" => "Custom Invoice Name" })

    I18n.with_locale(:en) do
      assert_equal "Custom Invoice Name", depot.invoice_description
    end
  end

  test "invoice_description falls back to depot model name with public name" do
    depot = depots(:bakery)
    depot.update!(invoice_names: {})

    description = depot.invoice_description

    assert_includes description, depot.public_name
    assert_includes description, Depot.model_name.human
  end

  test "map coordinates are required when depot is visible on maps" do
    depot = depots(:farm)
    depot.maps_visible = true
    depot.latitude = nil
    depot.longitude = nil

    assert_not depot.valid?
    assert_includes depot.errors[:latitude], "can't be blank"
    assert_includes depot.errors[:longitude], "can't be blank"
  end

  test "map coordinates must be in GPS ranges" do
    depot = depots(:farm)
    depot.latitude = 91
    depot.longitude = 181

    assert_not depot.valid?
    assert_includes depot.errors[:latitude], "must be less than or equal to 90"
    assert_includes depot.errors[:longitude], "must be less than or equal to 180"
  end

  test "mapped scope only returns public map depots with complete coordinates" do
    farm = depots(:farm)
    bakery = depots(:bakery)
    home = depots(:home)

    farm.update!(visible: true, maps_visible: true, latitude: 46.992979, longitude: 6.931932)
    bakery.update!(visible: false, maps_visible: true, latitude: 46.992979, longitude: 6.931932)
    home.update_columns(visible: true, maps_visible: true, latitude: 46.992979, longitude: nil)

    assert_equal [ farm ], Depot.mapped.to_a
  end

  test "with_map_coordinates scope filters depots with complete GPS positions" do
    farm = depots(:farm)
    bakery = depots(:bakery)
    home = depots(:home)

    farm.update_columns(latitude: 46.992979, longitude: 6.931932)
    bakery.update_columns(latitude: nil, longitude: 6.931932)
    home.update_columns(latitude: 46.992979, longitude: nil)

    assert_equal [ farm ], Depot.with_map_coordinates("true").to_a
    assert_equal [ home, bakery ], Depot.with_map_coordinates("false").to_a
  end

  test "enqueues geocoding when complete address changes and coordinates are blank" do
    with_geocoding_enabled do
      depot = depots(:bakery)
      depot.update_columns(latitude: nil, longitude: nil, street: nil, zip: nil, city: nil)

      assert_enqueued_with(job: DepotGeocodingJob) do
        depot.update!(street: "Rue du Marché 1", zip: "2000", city: "Neuchâtel")
      end
    end
  end

  test "enqueues geocoding when one coordinate is missing" do
    with_geocoding_enabled do
      depot = depots(:farm)
      depot.update_columns(latitude: 46.992979, longitude: nil)

      assert_enqueued_with(job: DepotGeocodingJob) do
        depot.update!(street: "Rue du Marché 1")
      end
    end
  end

  test "enqueues automatic geocoding when maps feature is disabled" do
    with_geocoding_enabled do
      disable_maps
      depot = depots(:bakery)
      depot.update_columns(latitude: nil, longitude: nil, street: nil, zip: nil, city: nil)

      assert_enqueued_with(job: DepotGeocodingJob) do
        depot.update!(street: "Rue du Marché 1", zip: "2000", city: "Neuchâtel")
      end
    end
  end

  test "does not enqueue automatic geocoding when coordinates are already set" do
    with_geocoding_enabled do
      depot = depots(:farm)
      depot.update_columns(latitude: 46.992979, longitude: 6.931932)

      assert_no_enqueued_jobs only: DepotGeocodingJob do
        depot.update!(street: "Rue du Marché 1")
      end
    end
  end

  private

  def disable_maps
    org(features: Current.org.features - [ :maps ])
  end

  def with_geocoding_enabled
    previous = Rails.application.config.x.geocoding.enabled
    Rails.application.config.x.geocoding.enabled = true
    yield
  ensure
    Rails.application.config.x.geocoding.enabled = previous
  end
end
