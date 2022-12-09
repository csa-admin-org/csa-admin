module Shop
  class SpecialDelivery < ApplicationRecord
    include HasFiscalYearScopes
    include TranslatedRichTexts

    self.table_name = 'shop_special_deliveries'

    attribute :open_last_day_end_time, :time_only

    translated_rich_texts :shop_text

    has_many :shop_orders,
      class_name: 'Shop::Order',
      dependent: :destroy,
      as: :delivery
    has_and_belongs_to_many :products,
      class_name: 'Shop::Product'

    default_scope { order(:date) }

    scope :past, -> { where(date: ...Date.current) }
    scope :coming, -> { where(date: Date.current..) }
    scope :open, -> { where(open: true) }

    validates :date, uniqueness: true
    validates :products, presence: true

    before_save :update_shop_products_count

    def self.next
      coming.open.order(:date).first
    end

    def self.current
      where(date: ..Date.current).visible.order(:date).last
    end

    def gid
      to_global_id.to_s
    end

    def display_name(format: :medium_long)
      "#{I18n.l(date, format: format)} (#{display_number})"
    end

    def display_number
      I18n.t 'activerecord.attributes.shop/special_delivery.special'
    end

    def shop_closing_at
      return unless open

      delay_in_days = open_delay_in_days.to_i.days
      end_time = open_last_day_end_time || Tod::TimeOfDay.parse('23:59:59')
      limit = end_time.on(date - delay_in_days)
    end

    def shop_open?
      return false unless open

      !shop_closing_at.past?
    end

    def shop_orders_count
      shop_orders.select { |o| o.state != 'cart' }.size
    end

    def available_shop_products(_depot)
      products
    end

    private

    def update_shop_products_count
      self.shop_products_count = products.size
    end
  end
end
