# frozen_string_literal: true

require "test_helper"

class Basket::CSVExporterTest < ActiveSupport::TestCase
  test "raises ArgumentError when neither delivery nor fiscal_year provided" do
    assert_raises(ArgumentError) do
      Basket::CSVExporter.new
    end
  end

  test "single delivery export includes member details columns" do
    travel_to "2024-04-01"
    delivery = deliveries(:monday_1)
    exporter = Basket::CSVExporter.new(delivery: delivery)

    csv = CSV.parse(exporter.generate, headers: true)

    # Member detail columns (translated)
    assert_includes csv.headers, Basket.human_attribute_name(:name)
    assert_includes csv.headers, Basket.human_attribute_name(:emails)
    assert_includes csv.headers, Basket.human_attribute_name(:phones)
    assert_includes csv.headers, Basket.human_attribute_name(:street)
    assert_includes csv.headers, Basket.human_attribute_name(:zip)
    assert_includes csv.headers, Basket.human_attribute_name(:city)
    assert_includes csv.headers, Basket.human_attribute_name(:food_note)
    assert_includes csv.headers, Basket.human_attribute_name(:delivery_note)

    # Should NOT have delivery columns in single delivery mode
    refute_includes csv.headers, Basket.human_attribute_name(:delivery_id)
    refute_includes csv.headers, Basket.human_attribute_name(:delivery_date)
  end

  test "single delivery export filename includes delivery info" do
    travel_to "2024-04-01"
    delivery = deliveries(:monday_1)
    exporter = Basket::CSVExporter.new(delivery: delivery)

    assert_match(/delivery-/, exporter.filename)
    assert_match(/20240401/, exporter.filename)
    assert_match(/\.csv$/, exporter.filename)
  end

  test "fiscal year export includes delivery columns" do
    fiscal_year = Current.org.fiscal_year_for(2024)
    exporter = Basket::CSVExporter.new(fiscal_year: fiscal_year)

    csv = CSV.parse(exporter.generate, headers: true)

    assert_includes csv.headers, Basket.human_attribute_name(:delivery_id)
    assert_includes csv.headers, Basket.human_attribute_name(:delivery_date)
  end

  test "fiscal year export excludes member details columns" do
    fiscal_year = Current.org.fiscal_year_for(2024)
    exporter = Basket::CSVExporter.new(fiscal_year: fiscal_year)

    csv = CSV.parse(exporter.generate, headers: true)

    refute_includes csv.headers, Basket.human_attribute_name(:name)
    refute_includes csv.headers, Basket.human_attribute_name(:emails)
    refute_includes csv.headers, Basket.human_attribute_name(:phones)
    refute_includes csv.headers, Basket.human_attribute_name(:street)
    refute_includes csv.headers, Basket.human_attribute_name(:food_note)
    refute_includes csv.headers, Basket.human_attribute_name(:delivery_note)
  end

  test "fiscal year export filename includes year" do
    fiscal_year = Current.org.fiscal_year_for(2024)
    exporter = Basket::CSVExporter.new(fiscal_year: fiscal_year)

    assert_match(/deliveries-/, exporter.filename)
    assert_match(/2024/, exporter.filename)
    assert_match(/\.csv$/, exporter.filename)
  end

  test "export includes common columns" do
    travel_to "2024-04-01"
    delivery = deliveries(:monday_1)
    exporter = Basket::CSVExporter.new(delivery: delivery)

    csv = CSV.parse(exporter.generate, headers: true)

    assert_includes csv.headers, Basket.human_attribute_name(:basket_id)
    assert_includes csv.headers, Basket.human_attribute_name(:membership_id)
    assert_includes csv.headers, Basket.human_attribute_name(:member_id)
    assert_includes csv.headers, Basket.human_attribute_name(:depot_id)
    assert_includes csv.headers, Basket.human_attribute_name(:depot)
    assert_includes csv.headers, Basket.human_attribute_name(:basket_size_id)
    assert_includes csv.headers, Basket.human_attribute_name(:quantity)
    assert_includes csv.headers, Basket.human_attribute_name(:state)
    assert_includes csv.headers, Basket.human_attribute_name(:description)
  end

  test "export omits depot group columns when depot groups are not used" do
    travel_to "2024-04-01"
    delivery = deliveries(:monday_1)
    exporter = Basket::CSVExporter.new(delivery: delivery)

    csv = CSV.parse(exporter.generate, headers: true)

    refute_includes csv.headers, Basket.human_attribute_name(:depot_group_id)
    refute_includes csv.headers, Basket.human_attribute_name(:depot_group)
  end

  test "adds shop variant quantities to basket complement columns" do
    travel_to "2024-04-01"
    delivery = deliveries(:thursday_1)
    basket = delivery.baskets.joins(:membership).find_by!(memberships: { member_id: members(:jane).id })
    create_shop_order(
      member: members(:jane),
      delivery: delivery,
      depot: basket.depot,
      items_attributes: {
        "0" => {
          product_variant_id: shop_product_variants(:bread_500).id,
          quantity: 3
        }
      })

    csv = CSV.parse(Basket::CSVExporter.new(delivery: delivery).generate, headers: true)
    row = csv.find { |entry| entry[Basket.human_attribute_name(:basket_id)] == basket.id.to_s }

    assert_equal "4", row[basket_complements(:bread).name]
  end

  test "checks for depot groups only once when none are used" do
    exporter = Basket::CSVExporter.new(delivery: deliveries(:monday_1))
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      sql = payload[:sql]
      queries << sql if sql.include?("SELECT 1 AS one") && sql.include?(%q("depots"."group_id" IS NOT NULL))
    end

    exporter.generate

    assert_equal 1, queries.size
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  test "export includes depot group columns when depot groups are used" do
    travel_to "2024-04-01"
    delivery = deliveries(:monday_1)
    group = DepotGroup.create!(
      names: { en: "Countryside route" },
      public_names: { en: "Public countryside route" })
    depots(:farm).update!(group: group)

    exporter = Basket::CSVExporter.new(delivery: delivery)
    csv = CSV.parse(exporter.generate, headers: true)

    assert_includes csv.headers, Basket.human_attribute_name(:depot_group_id)
    assert_includes csv.headers, Basket.human_attribute_name(:depot_group)

    row = csv.find { |r| r[Basket.human_attribute_name(:basket_id)] == baskets(:john_1).id.to_s }
    assert_equal group.id.to_s, row[Basket.human_attribute_name(:depot_group_id)]
    assert_equal "Countryside route", row[Basket.human_attribute_name(:depot_group)]
  end

  test "discarded member still has member_id in export" do
    travel_to "2024-04-01"
    delivery = deliveries(:monday_1)
    basket = baskets(:john_1)
    member = basket.member

    # Make member discardable and discard
    member.update_columns(state: "inactive")
    member.discard

    # After discard (but not anonymized), member_id should still be present
    exporter = Basket::CSVExporter.new(delivery: delivery)
    csv = CSV.parse(exporter.generate, headers: true)
    row = csv.find { |r| r[Basket.human_attribute_name(:basket_id)] == basket.id.to_s }
    assert_equal member.id.to_s, row[Basket.human_attribute_name(:member_id)]
  end

  test "anonymized member has nil member_id in export" do
    travel_to "2024-04-01"
    delivery = deliveries(:monday_1)
    basket = baskets(:john_1)
    member = basket.member

    # Before anonymization, member_id should be present
    exporter = Basket::CSVExporter.new(delivery: delivery)
    csv = CSV.parse(exporter.generate, headers: true)
    row = csv.find { |r| r[Basket.human_attribute_name(:basket_id)] == basket.id.to_s }
    assert_equal member.id.to_s, row[Basket.human_attribute_name(:member_id)]

    # Anonymize member
    member.update_columns(state: "inactive", discarded_at: Time.current, anonymized_at: Time.current)

    # After anonymization, member_id should be nil
    exporter = Basket::CSVExporter.new(delivery: delivery)
    csv = CSV.parse(exporter.generate, headers: true)
    row = csv.find { |r| r[Basket.human_attribute_name(:basket_id)] == basket.id.to_s }
    assert_nil row[Basket.human_attribute_name(:member_id)]
  end

  test "single delivery overlay uses host street, zip, city, and note" do
    travel_to "2024-04-01"
    members(:bob).update_column(:delivery_note, "Code 1234")
    HomeDeliveryAddress.create!(
      member: members(:bob),
      name: "Valentine Schneider",
      street: "Chantemerle 16",
      zip: "2000",
      city: "Neuchatel",
      note: "Leave at door",
      deliveries: [ deliveries(:monday_1) ])

    csv = CSV.parse(Basket::CSVExporter.new(delivery: deliveries(:monday_1)).generate, headers: true)
    bob = csv.find { |row| row[Basket.human_attribute_name(:name)] == "Bob Doe" }
    john = csv.find { |row| row[Basket.human_attribute_name(:name)] == "John Doe" }

    assert_equal "Valentine Schneider\nChantemerle 16", bob[Basket.human_attribute_name(:street)]
    assert_equal "2000", bob[Basket.human_attribute_name(:zip)]
    assert_equal "Neuchatel", bob[Basket.human_attribute_name(:city)]
    assert_equal "Leave at door", bob[Basket.human_attribute_name(:delivery_note)]
    assert_equal members(:john).street, john[Basket.human_attribute_name(:street)]
  end
end
