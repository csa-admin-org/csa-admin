module GroupBuying
  class OrderItem < ApplicationRecord
    self.table_name = 'group_buying_order_items'

    belongs_to :order,
      class_name: 'GroupBuying::Order',
      counter_cache: 'items_count',
      optional: false
    belongs_to :product, class_name: 'GroupBuying::Product', optional: false

    validates :price,
      presence: true,
      numericality: { greater_than_or_equal_to: 0 }
    validates :quantity,
      presence: true,
      numericality: { greater_than: 0 }
    validates :order_id, uniqueness: { scope: :product_id }

    def amount
      price * quantity
    end

    def product_id=(product_id)
      super
      self.price ||= product.price
    end
  end
end
