# frozen_string_literal: true

module Shop
  class SpecialDelivery < ApplicationRecord
    include HasDate
    include HasFiscalYear
    include TranslatedRichTexts
    include TranslatedAttributes

    self.table_name = "shop_special_deliveries"

    attribute :open_last_day_end_time, :time_only

    translated_attributes :title
    translated_rich_texts :shop_text

    has_many :shop_orders,
      class_name: "Shop::Order",
      dependent: :destroy,
      as: :delivery
    has_and_belongs_to_many :products,
      class_name: "Shop::Product"

    default_scope { order(:date) }

    scope :open, -> { where(open: true) }
    scope :depot_eq, ->(depot_id) {
      where.not("EXISTS (SELECT 1 FROM json_each(unavailable_for_depot_ids) WHERE json_each.value = ?)", depot_id.to_i)
    }

    validates :date, uniqueness: true, presence: true
    validates :products, presence: true
    validate :ensure_at_least_one_available_depot

    before_save :update_shop_products_count

    def self.ransackable_scopes(_auth_object = nil)
      super + %i[depot_eq]
    end

    def self.next
      coming.open.order(:date).first
    end

    def self.current
      where(date: ..Date.current).visible.order(:date).last
    end

    def gid
      to_global_id.to_s
    end

    def display_name(format: :medium)
      "#{I18n.l(date, format: format)} (#{display_number})"
    end

    def name; display_name; end

    def display_number
      I18n.t "activerecord.attributes.shop/special_delivery.special"
    end

    def title
      title_with_fallback.presence || self.class.model_name.human
    end

    def shop_closing_at
      return unless open

      delay_in_days = open_delay_in_days.to_i.days
      end_time = open_last_day_end_time || Tod::TimeOfDay.parse("23:59:59")
      end_time.on(date - delay_in_days)
    end

    def shop_open?(depot_id: nil, ignore_closing_at: false)
      return false unless Current.org.feature?("shop")
      return false unless open
      return false if depot_id && depot_id.in?(unavailable_for_depot_ids)

      ignore_closing_at || !shop_closing_at.past?
    end

    def available_for_depots
      Depot.where.not(id: unavailable_for_depot_ids)
    end

    def available_for_depot_ids
      available_for_depots.pluck(:id)
    end

    def available_for_depot_ids=(ids)
      self[:unavailable_for_depot_ids] =
        if open?
          Depot.pluck(:id) - ids.map(&:presence).compact.map(&:to_i)
        else
          []
        end
    end

    def shop_orders_count
      shop_orders.select { |o| o.state != "cart" }.size
    end

    def available_shop_products(_depot)
      products
    end

    def can_destroy?
      shop_orders.none?
    end

    private

    def ensure_at_least_one_available_depot
      if open? && available_for_depot_ids.none?
        self.errors.add(:available_for_depot_ids, :empty)
      end
    end

    def update_shop_products_count
      self.shop_products_count = products.size
    end
  end
end
