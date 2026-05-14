# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class Demo::SeederTest < ActiveSupport::TestCase
  test "raises error when not in demo tenant" do
    error = assert_raises(RuntimeError) do
      Demo::Seeder.new
    end

    assert_equal "Demo::Seeder can only run in a demo tenant", error.message
  end

  test "seed_basket_contents! keeps one piece quantity when ratios round down to zero" do
    with_demo_tenant do
      [ 22, 33, 44 ].each_with_index do |price, index|
        BasketSize.create!(
          names: { "en" => "Demo #{index}" },
          public_names: { "en" => "Demo basket #{index}" },
          price: price,
          activity_participations_demanded_annually: 1
        )
      end

      product = BasketContent::Product.create!(
        names: { "en" => "Salad" },
        unit: "pc",
        default_price: 2.5
      )

      seeder = Demo::Seeder.new
      seeder.instance_variable_set(:@products, [ product ])
      seeder.instance_variable_set(:@current_year_deliveries, [ deliveries(:monday_1) ])
      seeder.instance_variable_set(:@all_depots, Depot.all)

      assert_difference -> { BasketContent.count }, 1 do
        seeder.stub(:rand, 1) do
          seeder.send(:seed_basket_contents!)
        end
      end

      content = BasketContent.order(:id).last
      largest_basket_size = BasketSize.order(:price).last

      assert_equal "pc", content.unit
      assert_equal({ largest_basket_size.id => 1 }, content.basket_size_ids_quantities)
    end
  end
end
