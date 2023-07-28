module Shop
  class Product < ApplicationRecord
    self.table_name = 'shop_products'

    include TranslatedAttributes
    include TranslatedRichTexts

    translated_attributes :name, required: true
    translated_rich_texts :description

    default_scope { order_by_name }

    belongs_to :producer, class_name: 'Shop::Producer', optional: true
    belongs_to :basket_complement, optional: true
    has_many :variants,
      class_name: 'Shop::ProductVariant',
      dependent: :delete_all
    has_many :order_items, class_name: 'Shop::OrderItem', inverse_of: :product
    has_and_belongs_to_many :tags, class_name: 'Shop::Tag'
    has_and_belongs_to_many :special_deliveries,
      class_name: 'Shop::SpecialDelivery',
      counter_cache: 'shop_products_count'

    accepts_nested_attributes_for :variants, allow_destroy: true

    scope :available, -> { where(available: true) }
    scope :unavailable, -> { where(available: false) }
    scope :price_eq, ->(v) { joins(:variants).where('price = ?', v) }
    scope :price_gt, ->(v) { joins(:variants).where('price > ?', v) }
    scope :price_lt, ->(v) { joins(:variants).where('price < ?', v) }
    scope :stock_eq, ->(v) { joins(:variants).where('stock IS NOT NULL AND stock = ?', v) }
    scope :stock_gt, ->(v) { joins(:variants).where('stock IS NOT NULL AND stock > ?', v) }
    scope :stock_lt, ->(v) { joins(:variants).where('stock IS NOT NULL AND stock < ?', v) }
    scope :variant_name_cont, ->(str) {
      joins(:variants).merge(ProductVariant.name_cont(str))
    }
    scope :depot_eq, ->(depot_id) {
      where.not('? = ANY (unavailable_for_depot_ids)', depot_id)
    }
    scope :delivery_eq, ->(delivery_id) {
      where.not('? = ANY (unavailable_for_delivery_ids)', delivery_id)
    }

    validates :available, inclusion: [true, false]
    validates :variants, presence: true
    validates :variants, length: { is: 1, message: :single_variant }, if: :basket_complement_id?
    validate :ensure_at_least_one_available_variant

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
          .delivery_eq(delivery)
          .where('shop_products.basket_complement_id IS NULL OR basket_complements_deliveries.delivery_id = ?', delivery)
      if depot
        products = products.where.not('? = ANY (unavailable_for_depot_ids)', depot)
      end
      products.order_by_name
    end

    def available_for_depot_ids
      Depot.where.not(id: unavailable_for_depot_ids).pluck(:id)
    end

    def available_for_depot_ids=(ids)
      self[:unavailable_for_depot_ids] =
        if available?
          Depot.pluck(:id) - ids.map(&:to_i)
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
          Delivery.coming.shop_open.pluck(:id) - ids.map(&:to_i)
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

    def can_update?; true end

    def can_destroy?
      order_items.none?
    end

    def producer
      super || NullProducer.instance
    end

    private

    def ensure_at_least_one_available_variant
      if available? && variants.none?(&:available?)
        self.errors.add(:base, :at_least_one_available_variant)
      end
    end
  end
end
