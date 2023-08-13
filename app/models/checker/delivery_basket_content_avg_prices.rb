module Checker
  class DeliveryBasketContentAvgPrices
    MAX_DIFF = 0.001

    def self.check_all!
      Delivery.where(date: 1.month.ago..1.month.from_now).find_each do |m|
        new(m).check!
      end
    end

    def initialize(delivery)
      @delivery = delivery
    end

    def check!
      before = @delivery.basket_content_avg_prices.dup
      @delivery.update_basket_content_avg_prices!
      after = @delivery.basket_content_avg_prices

      if (before - after).abs >= MAX_DIFF
        Sentry.capture_message('Delivery basket content avg prices mismatch', extra: {
          delivery_id: @delivery.id,
          previous: previous,
          current: @delivery.basket_content_avg_prices
        })
      end
    end
  end
end
