module Shop
  class Order < ActiveRecord::Base
    include NumbersHelper
    include HasState

    self.table_name = 'shop_orders'

    has_states :cart, :pending, :invoiced

    belongs_to :member, optional: false
    belongs_to :delivery, optional: false
    has_many :items,
      class_name: 'Shop::OrderItem',
      inverse_of: :order,
      dependent: :destroy
    has_many :invoices, as: :object
    has_one :invoice, -> { not_canceled }, as: :object

    scope :all_without_cart, -> { where.not(state: 'cart') }

    before_validation :set_amount

    validates :items, presence: true, unless: :cart?
    validates :member_id, uniqueness: { scope: :delivery_id }
    validate :unique_items
    validate :ensure_maximum_weight_limit, unless: :cart?
    validate :ensure_minimal_amount, unless: :cart?

    accepts_nested_attributes_for :items,
      reject_if: ->(attrs) { attrs[:quantity].to_i.zero? },
      allow_destroy: true

    def depot
      delivery.baskets.joins(:membership).where(memberships: { member: member }).first.depot
    end

    def date
      created_at.to_date
    end

    def weight_in_kg
      items.sum(&:weight_in_kg)
    end

    def can_member_update?
      delivery.shop_open?
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
        update!(state: PENDING_STATE)
        items.each(&:save!) # update stocks
      end
    end

    def unconfirm!
      invalid_transition(:confirm!) unless pending?

      transaction do
        update!(state: CART_STATE)
        items.each { |i| i.save!(validate: false) } # update stocks
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
        invoice.cancel!
        update!(state: PENDING_STATE)
      end
    end

    def complements_description
      items.map { |item|
        next unless item.product.basket_complement

        case item.quantity
        when 1 then item.product.basket_complement.public_name
        else "#{item.quantity} x #{item.product.basket_complement.public_name}"
        end
      }.compact.to_sentence.presence
    end

    private

    def set_amount
      self.amount = items.reject(&:marked_for_destruction?).sum(&:amount)
    end

    def unique_items
      used_items = []
      items.each do |item|
        item_sign = [item.product_id, item.product_variant_id]
        if item_sign.in?(used_items)
          item.errors.add(:product_variant_id, :taken)
        end
        used_items << item_sign
      end
    end

    def ensure_maximum_weight_limit
      max = Current.acp.shop_order_maximum_weight_in_kg
      return unless max

      if weight_in_kg > max
        errors.add(:base, :maximum_weight_limit, max: kg(max))
      end
    end

    def ensure_minimal_amount
      min = Current.acp.shop_order_minimal_amount
      return unless min

      if amount < min
        errors.add(:base, :minimal_amount, min: cur(min))
      end
    end

    def create_invoice!
      self.invoices.create!(
        send_email: true,
        member: member,
        date: Date.today,
        items_attributes: items.map.with_index { |item, index|
          [index.to_s, {
            description: item.description,
            amount: item.amount
          }]
        }.to_h)
    end
  end
end
