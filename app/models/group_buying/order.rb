module GroupBuying
  class Order < ActiveRecord::Base
    self.table_name = 'group_buying_orders'

    attr_accessor :terms_of_service

    belongs_to :member, optional: false
    belongs_to :delivery, class_name: 'GroupBuying::Delivery', optional: false
    has_many :items, class_name: 'GroupBuying::OrderItem', inverse_of: :order, dependent: :destroy

    validate :items_must_be_present
    validate :terms_of_service_must_be_accepted

    before_create :set_amount

    accepts_nested_attributes_for :items,
      reject_if: ->(attrs) { attrs[:quantity].to_i.zero? }

    def date
      created_at.to_date
    end

    def can_destroy?
      false
    end

    def items_grouped_by_producer
      Product.available
        .joins(:producer).preload("rich_text_description_#{I18n.locale}".to_sym, producer: "rich_text_description_#{I18n.locale}".to_sym)
        .order('group_buying_producers.name')
        .order_by_name
        .map { |product|
          items.find { |i| i.product_id == product.id } ||
            self.items.new(product_id: product.id, quantity: 0)
        }.group_by { |i| i.product.producer }
    end

    private

    def items_must_be_present
      errors.add(:base, :no_items) if items.none?
    end

    # Avoid to have the error on terms_of_service as it breaks
    # the pretty_check_boxes with the field_with_errors wrapper
    def terms_of_service_must_be_accepted
      errors.add(:base, :terms_of_service_unchecked) unless @terms_of_service == '1'
    end

    def set_amount
      self.amount = items.sum(&:amount)
    end
  end
end
