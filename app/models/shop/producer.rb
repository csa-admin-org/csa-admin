# frozen_string_literal: true

module Shop
  class Producer < ApplicationRecord
    self.table_name = "shop_producers"

    include TranslatedRichTexts
    include Discardable
    include HasName

    default_scope { order_by_name }

    translated_rich_texts :description

    has_many :products, class_name: "Shop::Product"

    after_commit :reindex_product_search_entries,
      if: -> { saved_change_to_name? }

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

    private

    def reindex_product_search_entries
      SearchReindexDependentsJob.perform_later(self)
    end
  end
end
