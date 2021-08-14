module Shop
  class Order < ActiveRecord::Base
    include NumbersHelper
    include HasState

    self.table_name = 'shop_orders'

    has_states :cart, :pending, :invoiced

    belongs_to :member, optional: false
    belongs_to :delivery, optional: false
    has_many :items, class_name: 'Shop::OrderItem', inverse_of: :order, dependent: :destroy
    has_many :invoices
    has_one :invoice, -> { not_canceled }

    validates :items, presence: true
    validates :member_id, uniqueness: { scope: :delivery_id }
    validate :unique_items

    before_save :set_amount

    accepts_nested_attributes_for :items,
      reject_if: ->(attrs) { attrs[:quantity].to_i.zero? },
      allow_destroy: true

    def date
      created_at.to_date
    end

    def can_destroy?
      cart? || pending?
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
          # errors.add(:base, :invalid)
        end
        used_items << item_sign
      end
    end
  end
end
