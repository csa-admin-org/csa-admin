module Shop
  class OrderItem < ActiveRecord::Base
    self.table_name = 'shop_order_items'

    belongs_to :order, class_name: 'Shop::Order', optional: false
    belongs_to :product, class_name: 'Shop::Product', optional: false
    belongs_to :product_variant, class_name: 'Shop::ProductVariant', optional: false

    validates :item_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :quantity, presence: true, numericality: { greater_than: 0 }
    validates :order_id, uniqueness: { scope: %i[product_id product_variant_id] }

    def amount
      item_price * quantity
    end

    def item_price=(price)
      super if price.present?
    end

    def product_variant_id=(product_variant_id)
      super
      self.item_price = product_variant.price
    end
  end
end
