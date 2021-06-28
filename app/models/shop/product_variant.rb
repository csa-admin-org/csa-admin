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
  end
end
