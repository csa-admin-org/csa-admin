module PDF
  module Shop
    class Delivery < PDF::Base
      attr_reader :delivery, :current_time

      def initialize(delivery, order: nil)
        @delivery = delivery
        @orders =
          if order
            [order]
          else
            delivery.shop_orders
              .all_without_cart
              .includes(:member, items: [:product_variant, product: :producer])
              .sort_by { |order| [order.depot.name, order.member] }
          end
        super
        @current_time = Time.current

        @orders.each do |order|
          page(order)
          start_new_page unless @orders.last == order
        end
      end

      def filename
        [
          I18n.t('shop.title').parameterize,
          ::Delivery.model_name.human.parameterize,
          "##{delivery.number}",
          delivery.date.strftime('%Y%m%d')
        ].join('-') + '.pdf'
      end

      private

      def page(order)
        header(order.member, order.depot)
        content(order)
        footer
      end

      def header(member, depot)
        image acp_logo_io, at: [15, bounds.height - 20], width: 110
        bounding_box [bounds.width - 450, bounds.height - 20], width: 430, height: 120 do
          text member.name, size: 22, align: :right
          move_down 10
          text depot.public_name, size: 20, align: :right
          move_down 5
          text I18n.l(delivery.date), size: 20, align: :right
        end

        bounding_box [20, cursor - 15], width: 430, height: 15 do
          text I18n.t('shop.delivery.title'), size: 11
        end
      end

      def content(order)
        font_size 11
        move_down 15

        page_border = 20
        width = bounds.width - 2 * page_border
        quantity_width = 65
        order_items_width = width - quantity_width

        # Headers
        bounding_box [page_border, cursor], width: width, height: 25, position: :bottom do
          text_box ::Shop::OrderItem.human_attribute_name(:quantity), at: [0, cursor], style: :bold
          text_box ::Shop::Product.model_name.human, at: [quantity_width, cursor], style: :bold
        end

        move_up 0.2.cm
        font_size 11
        data = []

        # Order Items
        items = order.items.map { |item|
          item_description = [
            item.product.producer&.name,
            item.product.name,
            "<b>#{item.product_variant.name}</b>",
          ].compact.join(', ')
          [item_description, item.quantity]
        }.sort_by { |(desc, q)| desc }

        items.each do |item_description, quantity|
          data << [
            {
              content: quantity.to_s,
              width: quantity_width,
              padding_left: 20,
              align: :left
            },
            {
              content: item_description,
              width: order_items_width,
              padding_left: 0,
              align: :left
            }
          ]
        end

        table(
          data,
          row_colors: %w[DDDDDD FFFFFF],
          cell_style: { border_width: 0.5, border_color: 'AAAAAA', inline_format: true },
          position: :center) do |t|
            t.cells.borders = []
          end
      end

      def footer
        font_size 11
        bounding_box [0, 60], width: bounds.width do
          footer_text = Current.acp.shop_delivery_pdf_footer
          if footer_text.present?
            text footer_text, align: :center
          end
          move_down 25
          font_size 8
          text "– #{I18n.l(current_time, format: :short)} –", inline_format: true, align: :center
        end
      end
    end
  end
end
