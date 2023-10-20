module Shop
  class Order < ApplicationRecord
    include NumbersHelper
    include HasState
    include HasDescription

    self.table_name = 'shop_orders'

    attr_accessor :admin

    has_states :cart, :pending, :invoiced

    belongs_to :member, optional: false
    belongs_to :depot, optional: true
    belongs_to :delivery,
      polymorphic: true,
      optional: false
    has_many :items,
      class_name: 'Shop::OrderItem',
      inverse_of: :order,
      dependent: :destroy
    has_many :products,
      class_name: 'Shop::Product',
      through: :items
    has_many :products_displayed_in_delivery_sheets,
      class_name: 'Shop::Product',
      through: :items,
      source: :product_displayed_in_delivery_sheet
    has_many :invoices, as: :object
    has_one :invoice, -> { not_canceled }, as: :object

    scope :all_without_cart, -> { where.not(state: 'cart') }
    scope :_delivery_gid_eq, ->(gid) {
      where(delivery: GlobalID::Locator.locate(gid))
    }

    before_validation :set_amount

    validates :items, presence: true, if: -> { !cart? || admin }
    validates :member_id, uniqueness: { scope: [:delivery_type, :delivery_id] }
    validates :amount, numericality: true, if: :admin
    validates :amount_percentage,
      numericality: {
        greater_than_or_equal_to: -100,
        less_than_or_equal_to: 200,
        allow_nil: true
      }
    validate :unique_items
    validate :ensure_maximum_weight_limit
    validate :ensure_minimal_amount

    accepts_nested_attributes_for :items,
      reject_if: :reject_items,
      allow_destroy: true

    def self.ransackable_scopes(_auth_object = nil)
      super + %i[_delivery_gid_eq]
    end

    def self.complement_count(complement)
      joins(items: :product)
        .where(shop_products: { basket_complement_id: complement.id })
        .sum('shop_order_items.quantity')
    end

    def self.products_displayed_in_delivery_sheets
      joins(:products_displayed_in_delivery_sheets)
        .map(&:products_displayed_in_delivery_sheets)
        .flatten
        .uniq
        .sort_by(&:name)
    end

    def self.quantity_for(product)
      joins(:items)
        .where(shop_order_items: { product_id: product.id })
        .sum('shop_order_items.quantity')
    end

    def depot
      return super if depot_id?
      return member.shop_depot if member.use_shop_depot?

      case delivery
      when Delivery
        delivery.baskets.joins(:membership).where(memberships: { member: member }).first&.depot
      when Shop::SpecialDelivery
        member.memberships.during_year(delivery.date).first&.depot
      end
    end

    def date
      created_at.to_date
    end

    def delivery_gid=(gid)
      self.delivery = GlobalID::Locator.locate(gid)
    end

    def delivery_gid
      delivery&.gid
    end

    def weight_in_kg
      items.sum(&:weight_in_kg)
    end

    def shop_open?
      delivery.shop_open?(depot_id: depot&.id)
    end

    def can_member_update?
      shop_open?
    end

    def empty?
      items.none?
    end

    def can_update?
      cart? || pending?
    end

    def can_destroy?
      cart? || pending?
    end

    def can_invoice?
      pending?
    end

    def can_cancel?
      invoiced?
    end

    def confirm!
      invalid_transition(:confirm!) unless cart?

      transaction do
        items.each(&:validate!)
        items.each { |i| i.product_variant.decrement_stock!(i.quantity) }
        update!(
          state: PENDING_STATE,
          depot: depot)
      end
    end

    def unconfirm!
      invalid_transition(:confirm!) unless pending?

      transaction do
        items.each { |i| i.product_variant.increment_stock!(i.quantity) }
        update!(
          state: CART_STATE,
          depot: nil)
      end
    end

    def auto_invoice!
      delay = Current.acp.shop_order_automatic_invoicing_delay_in_days
      return unless delay
      return unless can_invoice?

      if (Date.today - delivery.date).to_i >= delay
        invoice!
      end
    end

    def invoice!
      invalid_transition(:invoice!) unless can_invoice?

      transaction do
        invoice = create_invoice!
        update!(state: INVOICED_STATE)
        invoice
      end
    end

    def cancel!
      invalid_transition(:cancel!) unless can_cancel?

      transaction do
        invoice.destroy_or_cancel!
        update!(state: PENDING_STATE)
      end
    end

    def complements_description(public_name: true)
      items.map { |item|
        next unless complement = item.product.basket_complement

        describe(complement, item.quantity, public_name: public_name)
      }.compact.to_sentence.presence
    end

    private

    def set_amount
      raw_amount = items.reject(&:marked_for_destruction?).sum(&:amount)
      if amount_percentage?
        self[:amount_before_percentage] = raw_amount
        self[:amount] = (raw_amount * (1 + amount_percentage / 100.0)).round_to_five_cents
      else
        self[:amount_before_percentage] = nil
        self[:amount] = raw_amount
      end
    end

    def unique_items
      used_items = []
      items.each do |item|
        item_sign = [item.product_id, item.product_variant_id]
        if item_sign.in?(used_items)
          item.errors.add(:product_variant_id, :taken)
          errors.add(:items, :taken) # required to show item error on form
        end
        used_items << item_sign
      end
    end

    def ensure_maximum_weight_limit
      return if cart?
      return if admin

      max = Current.acp.shop_order_maximum_weight_in_kg
      return unless max

      if weight_in_kg > max
        errors.add(:base, :maximum_weight_limit, max: kg(max))
      end
    end

    def ensure_minimal_amount
      return if cart?
      return if admin

      min = Current.acp.shop_order_minimal_amount
      return unless min

      if amount < min
        errors.add(:base, :minimal_amount, min: cur(min))
      end
    end

    def reject_items(attrs)
      if attrs[:quantity].to_i.zero?
        if attrs[:id].present?
          attrs.merge!(_destroy: 1)
          false
        else
          true
        end
      end
    end

    def create_invoice!
      self.invoices.create!(
        send_email: true,
        member: member,
        date: Date.today,
        amount_percentage: amount_percentage,
        items_attributes: items.map.with_index { |item, index|
          [index.to_s, {
            description: item.description,
            amount: item.amount
          }]
        }.to_h)
    end
  end
end
