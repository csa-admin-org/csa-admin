module Shop
  class Producer < ActiveRecord::Base
    self.table_name = 'shop_producers'

    include TranslatedRichTexts

    translated_rich_texts :description

    has_many :products, class_name: 'Shop::Product'

    validates :name, presence: true
    validates :website_url, format: {
      with: %r{\Ahttps?://.*\z},
      allow_blank: true
    }

    def can_update?; true end

    def can_destroy?
      products.none?
    end
  end
end
