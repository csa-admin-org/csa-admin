module Shop
  class OrderItem < ApplicationRecord
    include NumbersHelper

    self.table_name = "shop_order_items"

    belongs_to :order, class_name: "Shop::Order", optional: false, inverse_of: :items
    belongs_to :product, class_name: "Shop::Product", optional: false
    belongs_to :product_variant, class_name: "Shop::ProductVariant", optional: false
    belongs_to :product_displayed_in_delivery_sheet,
      -> { displayed_in_delivery_sheets },
      class_name: "Shop::Product",
      foreign_key: :product_id,
      optional: true
    has_one :delivery, through: :order

    validates :item_price, presence: true, numericality: true
    validates :quantity, presence: true, numericality: { greater_than: 0 }
    validates :order_id, uniqueness: { scope: %i[product_id product_variant_id] }
    validate :ensure_available_product_variant_stock
    validate :ensure_product_available_for_delivery

    before_save :update_product_variant_stock_of_pending_order!
    after_destroy :release_product_variant_stock!
    after_save :set_order_amount

    def amount
      (item_price * quantity).round_to_five_cents
    end

    def amount_after_percentage
      return amount unless order.amount_percentage

      (amount * (1 + order.amount_percentage / 100.0)).round_to_five_cents
    end

    def weight_in_kg
      return 0 unless product_variant.weight_in_kg

      product_variant.weight_in_kg * quantity
    end

    def item_price=(price)
      super if price.present?
    end

    def product_variant_id=(product_variant_id)
      super
      self.product = product_variant.product
      self.item_price = product_variant.price
    end

    def description
      [
        product.name,
        product_variant.name,
        "#{quantity}x #{cur(item_price, format: '%n')}"
      ].join(", ")
    end

    def quantity_was
      new_record? ? 0 : super
    end

    private

    def ensure_available_product_variant_stock
      if order.cart? || order_just_confirmed?
        unless product_variant.available_stock?(quantity)
          self.errors.add(:quantity, :less_than_or_equal_to,
            count: product_variant.stock)
        end
      elsif quantity_changed?
        change = quantity - quantity_was.to_i
        unless product_variant.available_stock?(change)
          self.errors.add(:quantity, :less_than_or_equal_to,
            count: quantity_was.to_i + product_variant.stock)
        end
      end
    end

    def ensure_product_available_for_delivery
      return unless order&.delivery
      return unless order&.depot

      @available_products ||= order.delivery.available_shop_products(order.depot)
      unless @available_products.include?(product)
        self.errors.add(:product, :not_available_for_delivery)
      end
    end

    def update_product_variant_stock_of_pending_order!
      return if order.state_changed? # handled by order#(un)confirm!
      return unless order.pending?

      change = quantity - quantity_was
      if change.nonzero?
        product_variant.decrement_stock! change
      end
    end

    def set_order_amount
      order.send(:set_amount)
      order.save
    end

    def release_product_variant_stock!
      return if order.cart?

      product_variant.increment_stock! quantity_was
    end

    def order_just_confirmed?
      order.state_previously_changed? &&
        order.state_previously_was == Order::CART_STATE &&
        order.state == Order::PENDING_STATE
    end

    def order_just_unconfirmed?
      order.state_previously_changed? &&
        order.state_previously_was == Order::PENDING_STATE &&
        order.state == Order::CART_STATE
    end
  end
end
