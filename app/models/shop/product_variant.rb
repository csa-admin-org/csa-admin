module Shop
  class ProductVariant < ActiveRecord::Base
    self.table_name = 'shop_product_variants'

    include TranslatedAttributes

    translated_attributes :name

    belongs_to :product, class_name: 'Shop::Product', optional: true

    validates :name, presence: true
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
  end
end
