# frozen_string_literal: true

require "test_helper"

class Liquid::AdminBasketDropTest < ActiveSupport::TestCase
  test "flags a temporary address when an overlay is present" do
    travel_to "2024-04-01"
    overlay = HomeDeliveryAddress.create!(
      member: members(:bob),
      name: "Valentine Schneider",
      street: "Chantemerle 16",
      zip: "2000",
      city: "Neuchatel",
      deliveries: [ deliveries(:monday_1) ])
    drop = Liquid::AdminBasketDrop.new(baskets(:bob_1), overlay: overlay)
    template = Liquid::Template.parse("{% if basket.temporary_address %}yes{% endif %}")

    assert_equal "yes", template.render!(
      "basket" => drop,
      strict_variables: true)
  end

  test "omits the flag when no overlay" do
    drop = Liquid::AdminBasketDrop.new(baskets(:john_1), overlay: nil)
    template = Liquid::Template.parse("{% if basket.temporary_address %}yes{% endif %}")

    assert_equal "", template.render!(
      "basket" => drop,
      strict_variables: true)
  end
end
