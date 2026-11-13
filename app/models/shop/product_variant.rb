# frozen_string_literal: true

module Shop
  class ProductVariant < ApplicationRecord
    self.table_name = "shop_product_variants"

    include TranslatedAttributes
    include Discardable

    UNITS = %w[kg pc].freeze

    translated_attributes :name, required: true

    default_scope { order(:price).order_by_name }

    belongs_to :product, class_name: "Shop::Product", optional: true
    belongs_to :basket_complement, inverse_of: :shop_product_variant, optional: true
    has_many :order_items, class_name: "Shop::OrderItem", inverse_of: :product_variant
    has_many :orders, through: :order_items
    has_many :uninvoiced_orders, -> { uninvoiced }, through: :order_items, source: :order

    scope :available, -> { where(available: true) }
    scope :unavailable, -> { where(available: false) }
    scope :available_for, ->(delivery) {
      variants = kept.available
      if delivery.is_a?(::Delivery)
        variants
          .left_joins(basket_complement: :deliveries)
          .where(<<~SQL.squish, delivery.id)
            shop_product_variants.basket_complement_id IS NULL
              OR basket_complements_deliveries.delivery_id = ?
          SQL
          .distinct
      else
        variants
      end
    }

    validates :available, inclusion: [ true, false ]
    validates :unit, inclusion: { in: UNITS }
    validates :basket_complement_id, uniqueness: true, allow_nil: true
    validates :price,
      presence: true,
      numericality: { greater_than_or_equal_to: 0 }
    validates :stock,
      numericality: { greater_than_or_equal_to: 0, allow_nil: true }
    validates :weight_in_kg,
      numericality: { greater_than: 0, allow_nil: true }
    validate :stock_scale
    validate :basket_complement_only_for_pieces
    validate :unit_locked_after_orders, on: :update

    before_validation :clear_weight_for_kilograms

    def kg?
      unit == "kg"
    end

    def pc?
      unit == "pc"
    end

    def unavailable?
      !available?
    end

    def out_of_stock?
      stock&.zero?
    end

    def available_for_delivery?(delivery)
      return false unless kept? && available?
      return true unless delivery.is_a?(::Delivery)
      return true unless basket_complement

      basket_complement.deliveries.include?(delivery)
    end

    def available_stock?(quantity = 1)
      return true if stock.nil?

      stock >= quantity
    end

    def decrement_stock!(by)
      return if stock.nil?

      decrement! :stock, by
    end

    def increment_stock!(by)
      return if stock.nil?

      increment! :stock, by
    end

    def can_discard?
      uninvoiced_orders.none?
    end

    def can_delete?
      order_items.none?
    end

    private

    def clear_weight_for_kilograms
      self.weight_in_kg = nil if kg?
    end

    def stock_scale
      return if stock.nil?

      if pc? && !whole_number?(stock)
        errors.add(:stock, :not_an_integer)
      elsif kg? && !at_most_two_decimals?(stock)
        errors.add(:stock, :invalid)
      end
    end

    def basket_complement_only_for_pieces
      return unless kg? && basket_complement_id.present?

      errors.add(:basket_complement_id, :invalid)
    end

    def unit_locked_after_orders
      return unless unit_changed?
      return if order_items.none?

      errors.add(:unit, :locked)
    end

    def whole_number?(value)
      value.to_d == value.to_d.round(0)
    end

    def at_most_two_decimals?(value)
      value.to_d == value.to_d.round(2)
    end
  end
end
