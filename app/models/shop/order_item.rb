module Shop
  class OrderItem < ActiveRecord::Base
    include NumbersHelper

    self.table_name = 'shop_order_items'

    belongs_to :order, class_name: 'Shop::Order', optional: false
    belongs_to :product, class_name: 'Shop::Product', optional: false
    belongs_to :product_variant, class_name: 'Shop::ProductVariant', optional: false

    validates :item_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :quantity, presence: true, numericality: { greater_than: 0 }
    validates :order_id, uniqueness: { scope: %i[product_id product_variant_id] }
    validate :ensure_available_product_variant_stock

    before_save :update_product_variant_stock!
    after_destroy :release_product_variant_stock!

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

    def description
      [
        product.name,
        product_variant.name,
        "#{quantity}x#{cur(item_price, format: '%n')}"
      ].join(', ')
    end

    private

    def ensure_available_product_variant_stock
      return unless quantity_changed?

      change = quantity - quantity_was.to_i
      unless product_variant.available_stock?(change)
        self.errors.add(:quantity, :less_than_or_equal_to,
          count: quantity_was.to_i + product_variant.stock)
      end
    end

    def update_product_variant_stock!
      return if order.cart?
      return unless quantity_changed?

      change = quantity - quantity_was.to_i
      product_variant.decrement_stock! change
    end

    def release_product_variant_stock!
      return if order.cart?

      product_variant.increment_stock! quantity
    end
  end
end
