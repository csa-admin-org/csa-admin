module Shop
  class DeliveryTotal
    include ActiveModel::Model
    attr_accessor :product, :product_variant, :quantity, :amount

    def self.all_by_producer(delivery)
      order_items = Order
        .where(delivery: delivery)
        .all_without_cart
        .eager_load(items: [ :product_variant, product: :producer ])
        .order(Arel.sql("shop_producers.name, shop_products.names->>'#{I18n.locale}', shop_product_variants.names->>'#{I18n.locale}'"))
        .flat_map(&:items)
        .group_by { |i| i.product.producer }

      order_items.map { |producer, items|
        all = items.group_by { |i|
          [ i.product, i.product_variant ]
        }.map { |(product, product_variant), items|
          new(
            product: product,
            product_variant: product_variant,
            quantity: items.sum(&:quantity),
            amount: items.sum(&:amount))
        }
        all << new(amount: items.sum(&:amount))
        [ producer, all ]
      }
    end
  end
end
