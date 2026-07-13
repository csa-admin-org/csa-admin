# frozen_string_literal: true

module ActiveAdmin
  class DeliveryOrderClause < OrderClause
    DELIVERY_DATE_FIELDS = %w[delivery_date deliveries.date].freeze

    def apply(chain)
      association = delivery_association(chain)
      return super unless association

      sorted = super(chain.left_joins(:delivery))
      return sorted if field.in?(DELIVERY_DATE_FIELDS)

      date = association.klass.arel_table[:date]
      sorted.order(order == "desc" ? date.desc : date.asc)
    end

    private

    def delivery_association(chain)
      association = chain.klass.reflect_on_association(:delivery)

      return unless association
      return if association.collection? || association.polymorphic?
      return unless association.klass == ::Delivery

      association
    end
  end
end
