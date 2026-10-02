# frozen_string_literal: true

require "test_helper"

class ProducerTest < ActiveSupport::TestCase
  test "find null producer" do
    producer = Producer.find("null")
    assert_equal NullProducer.instance, producer
  end

  test "can discard / delete" do
    producer = producers(:farm)
    product = shop_products(:bread)

    product.update!(producer: nil)
    producer.reload

    assert producer.can_delete?
    assert_not producer.can_discard?

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

  test "basket content product blocks delete and discard" do
    producer = producers(:farm)
    shop_products(:bread).update!(producer: nil)
    basket_content_products(:carrots).update!(producer: producer)
    producer.reload

    assert_not producer.can_delete?
    assert_not producer.can_discard?

    shop_products(:bread).update!(producer: producer)
    shop_products(:bread).discard
    producer.reload

    assert_not producer.can_discard?
  end
end
