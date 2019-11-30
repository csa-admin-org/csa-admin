module XLSX
  module GroupBuying
    class Delivery < Base
      include ActionView::Helpers::TextHelper

      def initialize(delivery, producer = nil)
        @delivery = delivery
        @order_items =
          @delivery
            .order_items
            .eager_load(order: [:invoice, :member], product: :producer)
            .order("members.name, group_buying_products.names->>'#{I18n.locale}'")
        @producers = @order_items.map { |i| i.product.producer }.uniq

        Array(producer || @producers).each do |p|
          build_producer_worksheet(p)
        end
      end

      def filename
        [
          t('group_buying/delivery'),
          "##{@delivery.id}",
          @delivery.date.strftime('%Y%m%d')
        ].join('-') + '.xlsx'
      end

      private

      def build_producer_worksheet(producer)
        order_items = @order_items.select { |i| i.product.producer == producer }
        worksheet_name = producer.name

        add_order_items_worksheet(worksheet_name, order_items)
      end

      def add_order_items_worksheet(name, order_items)
        add_worksheet(name)

        add_column(
          Member.human_attribute_name(:name),
          order_items.map { |i| i.order.member.name })
        add_column(
          ::GroupBuying::Order.model_name.human,
          order_items.map { |i| i.order.id },
          align: 'right',
          min_width: 12)
        add_column(
          ::GroupBuying::Product.model_name.human,
          order_items.map { |i| i.product.name })
        add_column(
          ::GroupBuying::OrderItem.human_attribute_name(:quantity),
          order_items.map { |i| i.quantity },
          align: 'right',
          min_width: 8)
        add_column(
          ::GroupBuying::OrderItem.human_attribute_name(:price),
          order_items.map { |i| i.price },
          align: 'right',
          min_width: 8)
        add_column(
          ::GroupBuying::OrderItem.human_attribute_name(:amount),
          order_items.map { |i| i.amount },
          align: 'right',
          min_width: 8)
      end

      def t(key, *args)
        I18n.t("delivery.#{key}", *args)
      end
    end
  end
end
