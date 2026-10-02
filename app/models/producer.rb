# frozen_string_literal: true

class Producer < ApplicationRecord
  include TranslatedRichTexts
  include Discardable
  include HasName

  default_scope { order_by_name }

  translated_rich_texts :description

  has_many :shop_products, class_name: "Shop::Product", inverse_of: :producer
  has_many :basket_content_products, class_name: "BasketContent::Product", inverse_of: :producer

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
    basket_content_products.none? &&
      shop_products.any?(&:discarded?) &&
      shop_products.none?(&:kept?)
  end

  def can_delete?
    shop_products.none? && basket_content_products.none?
  end

  private

  def reindex_product_search_entries
    SearchReindexDependentsJob.perform_later(self)
  end
end
