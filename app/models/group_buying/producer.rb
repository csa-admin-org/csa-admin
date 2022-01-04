module GroupBuying
  class Producer < ApplicationRecord
    self.table_name = 'group_buying_producers'

    include TranslatedRichTexts

    translated_rich_texts :description

    has_many :products, class_name: 'GroupBuying::Product'

    validates :name, presence: true
    validates :website_url, format: {
      with: %r{\Ahttps?://.*\z},
      allow_blank: true
    }

    def can_destroy?
      products.none?
    end
  end
end
