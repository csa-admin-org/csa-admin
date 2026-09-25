# frozen_string_literal: true

module Shop
  class Order < ApplicationRecord
    include NumbersHelper
    include HasState
    include HasDescription
    include HasAttachments
    include Searchable
    include GroupInvoice

    searchable :id, :amount, :delivery_date, priority: 5, date: :delivery_date

    def self.search_reindex_scope
      min = search_min_date
      deliveries = Delivery.where(date: min..) + Shop::SpecialDelivery.where(date: min..)
      all_without_cart.where(delivery: deliveries)
    end

    self.table_name = "shop_orders"

    attr_accessor :admin

    has_states :cart, :pending, :invoiced

    belongs_to :member, optional: false
    belongs_to :depot, optional: true
    belongs_to :delivery,
      polymorphic: true,
      optional: false
    has_many :items,
      class_name: "Shop::OrderItem",
      inverse_of: :order,
      dependent: :destroy
    has_many :products,
      class_name: "Shop::Product",
      through: :items
    has_many :products_displayed_in_delivery_sheets,
      class_name: "Shop::Product",
      through: :items,
      source: :product_displayed_in_delivery_sheet
    belongs_to :order_group,
      class_name: "Shop::OrderGroup",
      optional: true,
      inverse_of: :orders
    has_many :invoices, as: :entity
    has_one :invoice, -> { not_canceled }, as: :entity

    scope :all_without_cart, -> { where.not(state: "cart") }
    scope :uninvoiced, -> { where.not(state: "invoiced") }
    scope :with_effective_invoice, -> {
      joins(<<~SQL.squish)
        LEFT OUTER JOIN invoices order_invoices
          ON order_invoices.entity_type = 'Shop::Order'
          AND order_invoices.entity_id = shop_orders.id
          AND order_invoices.state != 'canceled'
        LEFT OUTER JOIN invoices group_invoices
          ON group_invoices.entity_type = 'Shop::OrderGroup'
          AND group_invoices.entity_id = shop_orders.order_group_id
          AND group_invoices.state != 'canceled'
      SQL
    }
    scope :_delivery_gid_eq, ->(gid) {
      where(delivery: GlobalID::Locator.locate(gid))
    }
    scope :during_year, ->(year) {
      deliveries = Delivery.during_year(year) + Shop::SpecialDelivery.during_year(year)
      where(delivery: deliveries)
    }

    before_validation :set_amount

    validates :items, presence: true, if: -> { !cart? || admin }
    validates :member_id, uniqueness: { scope: [ :delivery_type, :delivery_id ] }
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
      super + %i[during_year _delivery_gid_eq]
    end

    def self.complement_count(complement)
      joins(items: :product_variant)
        .where(shop_product_variants: { basket_complement_id: complement.id })
        .sum("shop_order_items.quantity")
    end

    def self.products_displayed_in_delivery_sheets
      joins(:products_displayed_in_delivery_sheets)
        .map(&:products_displayed_in_delivery_sheets)
        .flatten
        .uniq
        .sort_by(&:name)
    end

    def self.effective_invoice_totals(relation = all)
      orders = relation.unscope(:includes).offset(nil).limit(nil)
      rows = orders.with_effective_invoice.pluck(
        Arel.sql("shop_orders.amount"),
        Arel.sql("COALESCE(order_invoices.id, group_invoices.id)"))
      invoices = Invoice.where(id: rows.filter_map(&:last).uniq).index_by(&:id)
      group_order_counts = order_counts_for(invoices.values)
      paid = 0.to_d
      missing = 0.to_d

      rows.group_by(&:last).each do |invoice_id, group|
        invoice = invoices[invoice_id]
        next unless invoice

        visible = group.sum { |amount, _| amount.to_d }
        share = visible_invoice_share(invoice, visible, group.size, group_order_counts)
        paid += invoice.paid_amount.to_d * share
        missing += (invoice.amount - invoice.paid_amount.to_d) * share
      end

      {
        paid: paid,
        missing: missing,
        amount: orders.sum(:amount)
      }
    end

    def self.order_counts_for(invoices)
      group_ids = invoices.select(&:shop_order_group_type?).map(&:entity_id)
      return {} if group_ids.empty?

      where(order_group_id: group_ids).group(:order_group_id).count
    end
    private_class_method :order_counts_for

    def self.visible_invoice_share(invoice, visible, visible_count, group_order_counts)
      return 0 if invoice.amount.zero?
      return 1 unless invoice.shop_order_group_type?
      return 1 if group_order_counts[invoice.entity_id] == visible_count

      visible / invoice.amount
    end
    private_class_method :visible_invoice_share

    def self.quantity_for(product)
      joins(:items)
        .where(shop_order_items: { product_id: product.id })
        .sum("shop_order_items.quantity")
    end

    def depot
      return super if depot_id?
      return member.shop_depot if member.use_shop_depot?

      case delivery
      when Delivery
        delivery.baskets.joins(:membership).where(memberships: { member: member }).first&.depot
      when Shop::SpecialDelivery
        member.memberships.during_year(delivery.date).first&.depot || member.shop_depot
      end
    end

    def date
      created_at.to_date
    end

    def delivery_date
      delivery&.date
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

    def stale?
      cart? && (empty? || delivery.date < 1.week.ago)
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
      pending? && !group_invoice?
    end

    def can_invoice_period?
      pending? && group_invoice?
    end

    def can_cancel?
      invoiced? && invoice&.can_destroy_or_cancel?
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
      notify_admins_of_received_order!
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
      return unless Current.org.iban?

      delay = Current.org.shop_order_automatic_invoicing_delay_in_days
      return unless delay
      return unless can_invoice?

      if (Date.current - delivery.date).to_i >= delay
        invoice!
      end
    end

    def invoice!
      invalid_transition(:invoice!) unless can_invoice?

      transaction do
        invoice = create_invoice!
        update_columns(state: INVOICED_STATE)
        invoice
      end
    end

    def cancel!
      invalid_transition(:cancel!) unless can_cancel?
      return order_group.cancel! if order_group_id?

      transaction do
        invoice.destroy_or_cancel!
        update_columns(state: PENDING_STATE)
      end
    end

    # Defined on the class so it overrides has_one :invoice. A concern method would not.
    def invoice
      order_group_id? ? order_group&.invoice : super
    end

    def complements_description(public_name: true)
      items.map { |item|
        next unless complement = item.product_variant.basket_complement

        describe(complement, item.quantity, public_name: public_name)
      }.compact.to_sentence.presence
    end

    private

    def notify_admins_of_received_order!
      Admin.notify!(:new_shop_order, shop_order: self, skip: admin)
    end

    def set_amount
      kept_items = items.reject(&:marked_for_destruction?)
      raw_amount = kept_items.sum(&:amount)
      if amount_percentage?
        self[:amount_before_percentage] = raw_amount
        self[:amount] = kept_items.sum { |i| i.amount_after_percentage }
      else
        self[:amount_before_percentage] = nil
        self[:amount] = raw_amount
      end
    end

    def unique_items
      used_items = []
      items.each do |item|
        item_sign = [ item.product_id, item.product_variant_id ]
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

      max = Current.org.shop_order_maximum_weight_in_kg
      return unless max

      if weight_in_kg > max
        errors.add(:base, :maximum_weight_limit, max: kg(max))
      end
    end

    def ensure_minimal_amount
      return if cart?
      return if admin

      min = Current.org.shop_order_minimal_amount
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
        date: Date.current,
        amount_percentage: amount_percentage,
        items_attributes: items.map.with_index { |item, index|
          [ index.to_s, {
            description: item.description,
            amount: item.amount
          } ]
        }.to_h)
    end
  end
end
