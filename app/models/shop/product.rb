# frozen_string_literal: true

module Shop
  class Product < ApplicationRecord
    self.table_name = "shop_products"

    include TranslatedAttributes
    include TranslatedRichTexts
    include Discardable
    include Searchable

    searchable :names, :producer_name, priority: 4

    translated_attributes :name, required: true
    translated_rich_texts :description

    belongs_to :producer, class_name: "Shop::Producer", optional: true
    belongs_to :basket_complement, optional: true
    has_many :variants,
      -> { kept },
      class_name: "Shop::ProductVariant"
    has_many :all_variants,
      class_name: "Shop::ProductVariant",
      dependent: :delete_all
    has_many :order_items, class_name: "Shop::OrderItem", inverse_of: :product
    has_many :orders, through: :order_items
    has_many :uninvoiced_orders, -> { uninvoiced }, through: :order_items, source: :order
    has_and_belongs_to_many :tags, class_name: "Shop::Tag"
    has_and_belongs_to_many :special_deliveries,
      class_name: "Shop::SpecialDelivery",
      counter_cache: "shop_products_count"

    accepts_nested_attributes_for :variants, allow_destroy: true

    scope :available, -> { kept.where(available: true) }
    scope :unavailable, -> { where(available: false) }
    scope :price_eq, ->(v) { joins(:variants).where("shop_product_variants.price = ?", v.to_f) }
    scope :price_gt, ->(v) { joins(:variants).where("shop_product_variants.price > ?", v.to_f) }
    scope :price_lt, ->(v) { joins(:variants).where("shop_product_variants.price < ?", v.to_f) }
    scope :stock_eq, ->(v) { joins(:variants).where("stock IS NOT NULL AND stock = ?", v.to_i) }
    scope :stock_gt, ->(v) { joins(:variants).where("stock IS NOT NULL AND stock > ?", v.to_i) }
    scope :stock_lt, ->(v) { joins(:variants).where("stock IS NOT NULL AND stock < ?", v.to_i) }
    scope :variant_name_cont, ->(str) {
      joins(:variants).merge(ProductVariant.name_cont(str))
    }
    scope :depot_eq, ->(depot_id) {
      where.not("EXISTS (SELECT 1 FROM json_each(unavailable_for_depot_ids) WHERE json_each.value = ?)", depot_id.to_i)
    }
    scope :delivery_eq, ->(delivery_id) {
      where.not("EXISTS (SELECT 1 FROM json_each(unavailable_for_delivery_ids) WHERE json_each.value = ?)", delivery_id.to_i)
    }
    scope :displayed_in_delivery_sheets, -> {
      # Does not include product linked to a basket complement as they are
      # always displayed in delivery sheets (see #display_in_delivery_sheets).
      where(basket_complement_id: nil, display_in_delivery_sheets: true)
    }

    validates :available, inclusion: [ true, false ]
    validates :variants, presence: true
    validates :variants, length: { is: 1, message: :single_variant }, if: :basket_complement_id?
    validate :ensure_at_least_one_available_depot
    validate :ensure_at_least_one_available_variant
    validate :display_in_delivery_sheets_only_one_variant

    def self.ransackable_scopes(_auth_object = nil)
      super + %i[name_cont variant_name_cont] +
        %i[price_eq price_gt price_lt] +
        %i[stock_eq stock_gt stock_lt] +
        %i[depot_eq delivery_eq]
    end

    def self.available_for(delivery, depot = nil)
      products =
        available
          .left_joins(basket_complement: :deliveries)
          .delivery_eq(delivery.id)
          .where("shop_products.basket_complement_id IS NULL OR basket_complements_deliveries.delivery_id = ?", delivery)
      if depot
        products = products.where.not("EXISTS (SELECT 1 FROM json_each(unavailable_for_depot_ids) WHERE json_each.value = ?)", depot)
      end
      products.order_by_name
    end

    def state
      available? ? "available" : "unavailable"
    end

    def available_for_depot_ids
      Depot.where.not(id: unavailable_for_depot_ids).pluck(:id)
    end

    def available_for_depot_ids=(ids)
      self[:unavailable_for_depot_ids] =
        if available?
          Depot.pluck(:id) - ids.map(&:presence).compact.map(&:to_i)
        else
          []
        end
    end

    def available_for_delivery_ids
      Delivery.coming.shop_open.where.not(id: unavailable_for_delivery_ids).pluck(:id)
    end

    def available_for_delivery_ids=(ids)
      self[:unavailable_for_delivery_ids] =
        if available?
          Delivery.coming.shop_open.pluck(:id) - ids.map(&:presence).compact.map(&:to_i)
        else
          []
        end
    end

    def display_name(producer: false)
      txt = name
      txt += "*" if basket_complement_id?
      txt += " (#{send(:producer).name})" if producer && producer_id?
      txt
    end

    def display_in_delivery_sheets
      basket_complement_id? || super
    end

    def name_with_single_variant
      raise "Product has more than one variant" if variants.many?

      "#{name} (#{variants.first.name})"
    end

    def can_update?; true end

    def can_discard?
      uninvoiced_orders.none?
    end

    def can_delete?
      order_items.none?
    end

    def producer
      super || NullProducer.instance
    end

    def producer_name
      producer.name if producer_id?
    end

    private

    def search_relevant_changes?
      super || saved_change_to_producer_id?
    end

    def ensure_at_least_one_available_depot
      if available? && available_for_depot_ids.none?
        self.errors.add(:available_for_depot_ids, :empty)
      end
    end

    def ensure_at_least_one_available_variant
      if available? && variants.none?(&:available?)
        self.errors.add(:base, :at_least_one_available_variant)
      end
    end

    def display_in_delivery_sheets_only_one_variant
      if display_in_delivery_sheets? && variants.many?
        self.errors.add(:display_in_delivery_sheets, :only_one_variant)
      end
    end

    after_discard do
      variants.discard_all
    end
  end
end
