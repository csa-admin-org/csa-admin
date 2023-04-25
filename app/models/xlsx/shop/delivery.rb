module XLSX
  module Shop
    class Delivery < Base
      include ActionView::Helpers::TextHelper

      def initialize(delivery, producer = nil, depot: nil)
        @delivery = delivery
        orders = ::Shop::Order.where(delivery: delivery).all_without_cart
        if depot
          orders = orders.where(depot: depot)
        end
        @order_items =
          ::Shop::OrderItem
            .joins(:order)
            .merge(orders)
            .eager_load(:product_variant, product: :producer, order: [:invoice, :member, :depot])
            .order(Arel.sql("members.name, shop_products.names->>'#{I18n.locale}', shop_product_variants.names->>'#{I18n.locale}'"))
        @producers = @order_items.map { |i| i.product.producer }.uniq

        build_all_producers_worksheet unless producer
        Array(producer || @producers).each do |p|
          build_producer_worksheet(p)
        end
      end

      def filename
        [
          I18n.t('shop.title').parameterize,
          ::Delivery.model_name.human.parameterize,
          @delivery.display_number,
          @delivery.date.strftime('%Y%m%d')
        ].join('-') + '.xlsx'
      end

      private

      def build_all_producers_worksheet
        worksheet_name = I18n.t('shop.producers.all')
        add_order_items_worksheet(worksheet_name, @order_items)
      end

      def build_producer_worksheet(producer)
        order_items = @order_items.select { |i| i.product.producer == producer }
        worksheet_name = producer.name

        add_order_items_worksheet(worksheet_name, order_items, producer)
      end

      def add_order_items_worksheet(name, order_items, producer = nil)
        add_worksheet(name)

        add_column(
          ::Shop::Order.model_name.human,
          order_items.map { |i| i.order.id },
          align: 'right',
          min_width: 12)
        add_column(
          Member.human_attribute_name(:name),
          order_items.map { |i| i.order.member.name })
        add_column(
          Depot.model_name.human,
          order_items.map { |i| i.order.depot&.name })
        unless producer
          add_column(
            ::Shop::Producer.model_name.human,
            order_items.map { |i| i.product.producer.name })
        end
        add_column(
          ::Shop::Product.model_name.human,
          order_items.map { |i| i.product.name })
        add_column(
          ::Shop::ProductVariant.model_name.human,
          order_items.map { |i| i.product_variant.name })
        add_column(
          ::Shop::OrderItem.human_attribute_name(:quantity),
          order_items.map(&:quantity),
          align: 'right',
          min_width: 8)
        add_column(
          ::Shop::OrderItem.human_attribute_name(:price),
          order_items.map(&:item_price),
          align: 'right',
          min_width: 8)
        add_column(
          ::Shop::OrderItem.human_attribute_name(:amount),
          order_items.map(&:amount),
          align: 'right',
          min_width: 8)
      end
    end
  end
end
