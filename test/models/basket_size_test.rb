# frozen_string_literal: true

require "test_helper"

class BasketSizeTest < ActiveSupport::TestCase
  def ordered_names
    BasketSize.member_ordered.map(&:name)
  end

  test "#member_ordered" do
    assert_equal %w[Large Medium Small], ordered_names

    org(basket_sizes_member_order_mode: "price_asc")
    assert_equal %w[Small Medium Large], ordered_names

    org(basket_sizes_member_order_mode: "name_asc")
    assert_equal %w[Large Medium Small], ordered_names

    basket_sizes(:small).update_column(:member_order_priority, 0)
    assert_equal %w[Small Large Medium], ordered_names
  end

  test "price_for ignores deliveries with basket_size_price_percentage" do
    travel_to "2024-01-01"
    basket_size = basket_sizes(:medium)

    assert_equal 20, basket_size.price_for(2024)

    deliveries(:monday_1).update!(basket_size_price_percentage: 50)
    memberships(:john).baskets.where(delivery: deliveries(:monday_1)).update_all(basket_size_price: 10)

    assert_equal 20, basket_size.price_for(2024)
  end
end
