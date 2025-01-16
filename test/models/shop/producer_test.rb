# frozen_string_literal: true

require "test_helper"

class Shop::ProducerTest < ActiveSupport::TestCase
  test "find null producer" do
    producer = Shop::Producer.find("null")
    assert_equal Shop::NullProducer.instance, producer
  end

  test "can discard / delete" do
    producer = shop_producers(:farm)

    assert producer.can_delete?
    assert_not producer.can_discard?

    product = shop_products(:bread)
    product.update!(producer: producer)
    producer.reload

    assert_not producer.can_delete?
    assert_not producer.can_discard?

    product.discard
    producer.reload

    assert_not producer.can_delete?
    assert producer.can_discard?

    assert_changes -> { producer.discarded_at }, from: nil do
      producer.destroy
    end
    assert producer.discarded?
  end
end
