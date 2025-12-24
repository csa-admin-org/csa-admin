# frozen_string_literal: true

require "test_helper"

class ForcedDeliveryTest < ActiveSupport::TestCase
  test "validates uniqueness of delivery_id scoped to membership_id" do
    membership = memberships(:john)
    delivery = deliveries(:monday_1)

    ForcedDelivery.create!(membership: membership, delivery: delivery)

    duplicate = ForcedDelivery.new(membership: membership, delivery: delivery)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:delivery_id], "has already been taken"
  end

  test "validates delivery must be in membership period" do
    membership = memberships(:john)
    delivery = deliveries(:monday_future_1)

    forced_delivery = ForcedDelivery.new(membership: membership, delivery: delivery)

    assert_not forced_delivery.valid?
    assert_includes forced_delivery.errors[:delivery_id], "is not included in the list"
  end

  test "allows delivery within membership period" do
    membership = memberships(:john)
    delivery = deliveries(:monday_1)

    forced_delivery = ForcedDelivery.new(membership: membership, delivery: delivery)

    assert forced_delivery.valid?
  end
end
