# frozen_string_literal: true

require "test_helper"

class BasketsBasketComplementsUpdaterJobTest < ActiveJob::TestCase
  test "enqueues after the transaction commits" do
    delivery = deliveries(:monday_1)
    complement = basket_complements(:eggs)

    assert_enqueued_jobs 1, only: BasketsBasketComplementsUpdaterJob do
      Delivery.transaction do
        delivery.basket_complements << complement

        assert_no_enqueued_jobs only: BasketsBasketComplementsUpdaterJob
      end
    end
  end
end
