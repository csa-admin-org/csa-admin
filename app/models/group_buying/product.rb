module GroupBuying
  class Product < ApplicationRecord
    self.table_name = 'group_buying_products'

    include TranslatedAttributes
    include TranslatedRichTexts

    translated_attributes :name
    translated_rich_texts :description

    default_scope { order_by_name }

    belongs_to :producer, class_name: 'GroupBuying::Producer', optional: false
    has_many :order_items, class_name: 'GroupBuying::OrderItem', inverse_of: :product

    scope :available, -> { where(available: true) }

    validates :name, presence: true
    validates :price,
      presence: true,
      numericality: { greater_than_or_equal_to: 0 }
    validates :available, inclusion: [true, false]

    def can_destroy?
      order_items.none?
    end
  end
end
