module Shop
  class Producer < ApplicationRecord
    self.table_name = "shop_producers"

    include TranslatedRichTexts
    include Discardable

    default_scope { order(:name) }

    translated_rich_texts :description

    has_many :products, class_name: "Shop::Product"

    validates :name, presence: true
    validates :website_url, format: {
      with: %r{\Ahttps?://.*\z},
      allow_blank: true
    }

    def self.find(*args)
      return NullProducer.instance if args.first == "null"

      super
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
