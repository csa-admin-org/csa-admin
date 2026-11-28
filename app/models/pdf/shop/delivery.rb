# frozen_string_literal: true

module PDF
  module Shop
    class Delivery < PDF::Base
      ITEMS_PER_PAGE = 26

      Page = Data.define(:member_name, :depot_name, :page, :total_pages, :items)
      Item = Data.define(:quantity, :description)

      attr_reader :delivery, :current_time

      def initialize(delivery, order: nil, depot: nil)
        @delivery = delivery
        @orders = load_orders(order: order, depot: depot)
        @current_time = Time.current
      end

      def filename
        [
          I18n.t("shop.title").parameterize,
          ::Delivery.model_name.human.parameterize,
          delivery.display_number,
          delivery.date.strftime("%Y%m%d")
        ].join("-") + ".pdf"
      end

      private

      def template_path
        "pdfs/shop/deliveries/show"
      end

      def stylesheets
        %w[pdf/shop_delivery]
      end

      def creation_date
        current_time
      end

      def view_assigns
        {
          logo_data_uri: org_logo_data_uri(size: 110),
          delivery_date: I18n.l(delivery.date),
          footer_text: Current.org.shop_delivery_pdf_footer.presence,
          generated_at_label: "– #{I18n.l(current_time, format: :short)} –",
          pages: build_pages
        }
      end

      def load_orders(order:, depot:)
        return [ order ] if order

        orders =
          delivery.shop_orders
            .all_without_cart
            .includes(:member, :depot, items: [ :product_variant, product: :producer ])
        orders = orders.where(depot: depot) if depot
        orders.sort_by { |o| [ o.depot&.name.to_s, o.member ] }
      end

      def build_pages
        @orders.flat_map { |order| build_order_pages(order) }
      end

      def build_order_pages(order)
        total_pages = (order.items.count / ITEMS_PER_PAGE.to_f).ceil
        order.items.each_slice(ITEMS_PER_PAGE).with_index.map do |items_slice, i|
          Page.new(
            member_name: order.member.name,
            depot_name: order.depot&.public_name,
            page: i + 1,
            total_pages: total_pages,
            items: build_items(items_slice)
          )
        end
      end

      def build_items(items_slice)
        items_slice
          .map { |item| [ item_description(item), item ] }
          .sort_by(&:first)
          .map do |description, item|
            Item.new(
              quantity: item.product_variant.kg? ? item.delivery_quantity_label : item.displayed_quantity,
              description: description
            )
          end
      end

      def item_description(item)
        parts = [ item.product.name, item.product_variant.name ]
        if item.product.producer && item.product.producer_id?
          parts << item.product.producer.name
        end
        parts.join(", ")
      end
    end
  end
end
