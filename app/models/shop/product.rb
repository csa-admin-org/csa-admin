module Shop
  class Product < ActiveRecord::Base
    self.table_name = 'shop_products'

    include TranslatedAttributes
    include TranslatedRichTexts

    translated_attributes :name
    translated_rich_texts :description

    belongs_to :producer, class_name: 'Shop::Producer', optional: true
    belongs_to :basket_complement, optional: true
    has_many :variants,
      -> { order("price").merge(ProductVariant.order_by_name) },
      class_name: 'Shop::ProductVariant',
      dependent: :delete_all
    has_many :order_items, class_name: 'Shop::OrderItem', inverse_of: :product
    has_and_belongs_to_many :tags, class_name: 'Shop::Tag'

    accepts_nested_attributes_for :variants, allow_destroy: true

    scope :available, -> { where(available: true) }
    scope :unavailable, -> { where(available: false) }
    scope :price_equals, ->(v) { joins(:variants).where('price = ?', v) }
    scope :price_greater_than, ->(v) { joins(:variants).where('price > ?', v) }
    scope :price_less_than, ->(v) { joins(:variants).where('price < ?', v) }
    scope :stock_equals, ->(v) { joins(:variants).where('stock IS NOT NULL AND stock = ?', v) }
    scope :stock_greater_than, ->(v) { joins(:variants).where('stock IS NOT NULL AND stock > ?', v) }
    scope :stock_less_than, ->(v) { joins(:variants).where('stock IS NOT NULL AND stock < ?', v) }
    scope :variant_name_contains, ->(str) {
      joins(:variants).merge(ProductVariant.name_contains(str))
    }

    validates :name, presence: true
    validates :available, inclusion: [true, false]
    validates :variants, presence: true
    validates :variants, length: { is: 1, message: :single_variant }, if: :basket_complement_id?

    def self.ransackable_scopes(_auth_object = nil)
      super + %i[name_contains variant_name_contains] +
        %i[price_equals price_greater_than price_less_than] +
        %i[stock_equals stock_greater_than stock_less_than]
    end

    def self.available_for(delivery, depot = nil)
      products =
        available
          .left_joins(basket_complement: :deliveries)
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
      self[:unavailable_for_depot_ids] = Depot.pluck(:id) - ids.map(&:to_i)
    end

    def display_name
      txt = name
      txt += "*" if basket_complement_id?
      txt
    end

    def can_update?; true end

    def can_destroy?
      order_items.none?
    end
  end
end
