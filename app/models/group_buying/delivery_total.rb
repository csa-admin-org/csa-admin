module GroupBuying
  class DeliveryTotal
    include ActiveModel::Model
    attr_accessor :product, :quantity, :amount

    def self.all_by_producer(delivery)
      order_items = delivery
        .orders_without_canceled
        .eager_load(items: { product: :producer })
        .order("group_buying_producers.name, group_buying_products.names->>'#{I18n.locale}'")
        .flat_map(&:items)
        .group_by { |i| i.product.producer }

      order_items.map { |producer, items|
        all = items.group_by(&:product).map { |product, items|
          new(
            product: product,
            quantity: items.sum(&:quantity),
            amount: items.sum(&:amount))
        }
        all << new(amount: items.sum(&:amount))
        [producer, all]
      }
    end
  end
end
