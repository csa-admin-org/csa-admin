module Shop
  class Tag < ApplicationRecord
    self.table_name = 'shop_tags'

    include TranslatedAttributes
    translated_attributes :name, required: true

    has_and_belongs_to_many :products, class_name: 'Shop::Product'

    default_scope { order_by_name }

    def display_name
      [emoji, name].compact.join(' ')
    end

    def can_update?; true end
    def can_destroy?; true end
  end
end
