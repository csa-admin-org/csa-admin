# frozen_string_literal: true

require "test_helper"

class Liquid::BasketContentDropTest < ActiveSupport::TestCase
  test "exposes the producer name without requiring it in the template" do
    travel_to "2024-04-01"
    basket = baskets(:jane_1)
    product = basket_content_products(:carrots)
    product.update!(producer: producers(:farm))
    create_basket_content(
      delivery: basket.delivery,
      product: product,
      basket_size_ids_quantities: { large_id => 1 },
      depots: Depot.all,
      unit: "pc")

    drop = Liquid::BasketContentDrop.new(basket, basket.contents.first)
    template = Liquid::Template.parse("{{ content.product }} {{ content.producer }}")

    assert_equal "Carrots", drop.product
    assert_equal "Farm", drop.producer
    assert_equal "Carrots Farm", template.render!("content" => drop)

    product.update!(producer: nil)
    drop = Liquid::BasketContentDrop.new(basket, basket.contents.first)

    assert_nil drop.producer
  end
end
