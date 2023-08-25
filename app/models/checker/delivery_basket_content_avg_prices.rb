module Checker
  class DeliveryBasketContentAvgPrices
    MAX_DIFF = 0.01

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

      if diffs(before, after).any? { |d| d >= MAX_DIFF }
        Sentry.capture_message('Delivery basket content avg prices mismatch', extra: {
          delivery_id: @delivery.id,
          before: before,
          after: after
        })
      end
    end

    def diffs(before, after)
      before = before.values.sort
      after = after.values.sort
      before.zip(after).map { |b, a| (b - a).abs }
    end
  end
end
