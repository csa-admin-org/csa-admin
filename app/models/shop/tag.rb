module Shop
  class Tag < ApplicationRecord
    self.table_name = "shop_tags"

    include TranslatedAttributes
    include Discardable

    default_scope { order_by_name }

    translated_attributes :name, required: true

    has_and_belongs_to_many :products, class_name: "Shop::Product"

    def display_name
      [ emoji, name ].compact.join(" ")
    end

    def can_update?; true end

    def can_discard?
      products.any?(&:discarded?) && products.none?(&:kept?)
    end

    def can_delete?
      products.none?
    end
  end
end
