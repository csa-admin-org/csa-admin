# frozen_string_literal: true

require "test_helper"

class Notification::BasketComplementDeliveryCountTest < ActiveSupport::TestCase
  test "notifies one day before a linked delivery by default" do
    bread = basket_complements(:bread)
    bread.update!(emails: "bread-supplier@example.com", language: "en")
    delivery = deliveries(:thursday_1)

    travel_to delivery.date - 1.day do
      assert_difference -> { BasketComplementMailer.deliveries.size }, 1 do
        Notification::BasketComplementDeliveryCount.notify
        perform_enqueued_jobs
      end
    end

    assert_equal [ "bread-supplier@example.com" ], BasketComplementMailer.deliveries.last.to
  end

  test "notifies two days before a linked delivery with a custom offset" do
    bread = basket_complements(:bread)
    bread.update!(emails: "bread-supplier@example.com", notify_days_before_delivery: 2)
    delivery = deliveries(:thursday_1)

    travel_to delivery.date - 1.day do
      assert_no_difference -> { BasketComplementMailer.deliveries.size } do
        Notification::BasketComplementDeliveryCount.notify
        perform_enqueued_jobs
      end
    end

    travel_to delivery.date - 2.days do
      assert_difference -> { BasketComplementMailer.deliveries.size }, 1 do
        Notification::BasketComplementDeliveryCount.notify
        perform_enqueued_jobs
      end
    end
  end

  test "notifies on the delivery day with a same-day offset" do
    bread = basket_complements(:bread)
    bread.update!(emails: "bread-supplier@example.com", notify_days_before_delivery: 0)
    delivery = deliveries(:thursday_1)

    travel_to delivery.date - 1.day do
      assert_no_difference -> { BasketComplementMailer.deliveries.size } do
        Notification::BasketComplementDeliveryCount.notify
        perform_enqueued_jobs
      end
    end

    travel_to delivery.date do
      assert_difference -> { BasketComplementMailer.deliveries.size }, 1 do
        Notification::BasketComplementDeliveryCount.notify
        perform_enqueued_jobs
      end
    end
  end

  test "notifies two deliveries independently" do
    bread = basket_complements(:bread)
    bread.update!(emails: "bread-supplier@example.com")

    assert_difference -> { BasketComplementMailer.deliveries.size }, 2 do
      deliveries(:thursday_1, :thursday_2).each do |delivery|
        travel_to delivery.date - 1.day do
          Notification::BasketComplementDeliveryCount.notify
          perform_enqueued_jobs
        end
      end
    end
  end

  test "notifies complements with different offsets for the same delivery separately" do
    delivery = deliveries(:thursday_1)
    bread = basket_complements(:bread)
    bread.update!(emails: "bread-supplier@example.com", notify_days_before_delivery: 1)

    eggs = basket_complements(:eggs)
    eggs.update!(emails: "eggs-supplier@example.com", notify_days_before_delivery: 2)

    travel_to delivery.date - 2.days do
      BasketsBasketComplement.create!(basket: baskets(:jane_1), basket_complement: eggs, price: eggs.price)

      assert_difference -> { BasketComplementMailer.deliveries.size }, 1 do
        Notification::BasketComplementDeliveryCount.notify
        perform_enqueued_jobs
      end
    end
    assert_equal [ "eggs-supplier@example.com" ], BasketComplementMailer.deliveries.last.to

    travel_to delivery.date - 1.day do
      assert_difference -> { BasketComplementMailer.deliveries.size }, 1 do
        Notification::BasketComplementDeliveryCount.notify
        perform_enqueued_jobs
      end
    end
    assert_equal [ "bread-supplier@example.com" ], BasketComplementMailer.deliveries.last.to
  end

  test "does not notify a complement without emails" do
    travel_to deliveries(:thursday_1).date - 1.day do
      assert_no_difference -> { BasketComplementMailer.deliveries.size } do
        Notification::BasketComplementDeliveryCount.notify
        perform_enqueued_jobs
      end
    end
  end

  test "does not notify when the target delivery is not linked to the complement" do
    bread = basket_complements(:bread)
    bread.update!(emails: "bread-supplier@example.com")

    travel_to deliveries(:monday_1).date - 1.day do
      assert_no_difference -> { BasketComplementMailer.deliveries.size } do
        Notification::BasketComplementDeliveryCount.notify
        perform_enqueued_jobs
      end
    end
  end

  test "does not notify when the delivery count is zero" do
    eggs = basket_complements(:eggs)
    eggs.update!(emails: "eggs-supplier@example.com")

    travel_to deliveries(:thursday_1).date - 1.day do
      assert_no_difference -> { BasketComplementMailer.deliveries.size } do
        Notification::BasketComplementDeliveryCount.notify
        perform_enqueued_jobs
      end
    end
  end
end
