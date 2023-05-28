module Checker
  class DeliveryBasketContentAvgPrices
    def self.check_all!
      Delivery.where(date: 1.month.ago..1.month.from_now).find_each do |m|
        new(m).check!
      end
    end

    def initialize(delivery)
      @delivery = delivery
    end

    def check!
      previous = @delivery.basket_content_avg_prices.dup
      @delivery.update_basket_content_avg_prices!
      if previous != @delivery.basket_content_avg_prices
        Sentry.capture_message('Delivery basket content avg prices mismatch', extra: {
          delivery_id: @delivery.id,
          previous: previous,
          current: @delivery.basket_content_avg_prices
        })
      end
    end
  end
end
