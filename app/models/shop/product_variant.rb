module Shop
  class ProductVariant < ApplicationRecord
    self.table_name = 'shop_product_variants'

    include TranslatedAttributes

    translated_attributes :name, required: true

    default_scope { order_by_name.order(:price) }

    belongs_to :product, class_name: 'Shop::Product', optional: true
    has_many :order_items, class_name: 'Shop::OrderItem', inverse_of: :product_variant

    scope :available, -> { where(available: true) }
    scope :unavailable, -> { where(available: false) }

    validates :available, inclusion: [true, false]
    validates :price,
      presence: true,
      numericality: { greater_than_or_equal_to: 0 }
    validates :stock,
      numericality: { greater_than_or_equal_to: 0, allow_nil: true }
    validates :weight_in_kg,
      numericality: { greater_than: 0, allow_nil: true }

    def out_of_stock?
      stock&.zero?
    end

    def available_stock?(quantity = 1)
      return true if stock.nil?

      stock >= quantity
    end

    def decrement_stock!(by)
      return if stock.nil?

      decrement! :stock, by
    end

    def increment_stock!(by)
      return if stock.nil?

      increment! :stock, by
    end

    def can_destroy?
      order_items.none?
    end
  end
end
