module Shop
  class Tag < ActiveRecord::Base
    self.table_name = 'shop_tags'

    include TranslatedAttributes
    translated_attributes :name

    has_and_belongs_to_many :products, class_name: 'Shop::Product'

    default_scope { order_by_name }

    validates :name, presence: true

    def display_name
      [emoji, name].compact.join(' ')
    end

    def can_destroy?; true end
  end
end
