module PDF
  class Delivery < Base
    attr_reader :delivery, :current_time

    def initialize(delivery, depot = nil)
      @delivery = delivery
      super
      @current_time = Time.current
      basket_ids = delivery.baskets.not_empty.pluck(:id)
      @baskets = Basket.where(id: basket_ids).includes(:member, :baskets_basket_complements, membership: :member).order('members.name')
      @depots =
        if depot
          [depot]
        else
          Depot.where(id: @baskets.pluck(:depot_id).uniq).order(:name)
        end
      if Current.acp.feature?('shop')
        @shop_orders =
          @delivery
            .shop_orders
            .all_without_cart
            .includes(items: { product: :basket_complement })
      end

      basket_per_page = Current.acp.delivery_pdf_show_phones? ? 15 : 22

      @depots.each do |dist|
        baskets = @baskets.where(depot: dist)
        basket_sizes = basket_sizes_for(baskets)
        total_pages = (baskets.count / basket_per_page.to_f).ceil

        baskets.each_slice(basket_per_page).with_index do |slice, i|
          page_n = i + 1
          page(dist, slice, baskets, basket_sizes, page: page_n, total_pages: total_pages)
          start_new_page unless page_n == total_pages
        end
        start_new_page unless @depots.last == dist
      end
    end

    def filename
      [
        ::Delivery.human_attribute_name(:signature_sheets).parameterize,
        ::Delivery.model_name.human.parameterize,
        "##{delivery.number}",
        delivery.date.strftime('%Y%m%d')
      ].join('-') + '.pdf'
    end

    private

    def info
      super.merge(Title: "#{::Delivery.human_attribute_name(:signature_sheets)} #{delivery.date}")
    end

    def page(depot, page_baskets, baskets, basket_sizes, page:, total_pages:)
      header(depot, page: page, total_pages: total_pages)
      content(depot, page_baskets, baskets, basket_sizes)
      footer
    end

    def header(depot, page:, total_pages:)
      image acp_logo_io, at: [15, bounds.height - 20], width: 110
      if announcement = Announcement.for(delivery, depot)
        bounding_box [20, bounds.height - 140], width: 300, height: 70 do
          text announcement.text,
            size: 13,
            style: :bold,
            leading: 4,
            valign: :center
        end
      end
      bounding_box [bounds.width - 370, bounds.height - 20], width: 350, height: 120 do
        text depot.public_name, size: 24, align: :right
        move_down 5
        text I18n.l(delivery.date), size: 24, align: :right
        if total_pages > 1
          move_down 5
          text "#{page} / #{total_pages}", size: 24, align: :right
        end
      end
    end

    def content(depot, page_baskets, baskets, basket_sizes)
      shop_orders = @shop_orders&.where(member_id: baskets.pluck(:member_id))
      show_shop_orders = @delivery.shop_open && shop_orders&.any?
      basket_complements = basket_complements_for(baskets, show_shop_orders && shop_orders)

      font_size 11
      move_down 2.cm

      bs_size = basket_sizes.size
      bc_size = basket_complements.size
      bc_size += 1 if show_shop_orders

      page_border = 20
      width = bounds.width - 2 * page_border
      number_width = 25
      signature_width = 125
      member_name_width = width - (bs_size + bc_size) * number_width - signature_width

      # Headers Basket Sizes and Complements
      bounding_box [page_border, cursor], width: width, height: 25, position: :bottom do
        text_box '', width: member_name_width, at: [0, cursor]
        basket_sizes.each_with_index do |bs, i|
          text_box bs.public_name,
            rotate: 45,
            at: [member_name_width + i * 25 + 7, cursor + 8],
            valign: :center
        end
        basket_complements.each_with_index do |bc, i|
          text_box bc.public_name,
            rotate: 45,
            at: [member_name_width + (bs_size + i) * 25 + 7, cursor + 8],
            valign: :center
        end
        if show_shop_orders
          text_box I18n.t('shop.title_orders', count: 1),
            rotate: 45,
            at: [member_name_width + (bs_size + bc_size - 1) * 25 + 7, cursor + 8],
            valign: :center
        end
      end

      move_up 0.4.cm
      font_size 12
      data = []

      # Depot Totals
      total_line = [
        content: I18n.t('delivery.totals'),
        width: member_name_width,
        align: :right,
        padding_right: 15
      ]
      all_baskets = baskets.reject(&:absent?)
      basket_sizes.each do |bs|
        baskets_with_size = all_baskets.select { |b| b.basket_size_id == bs.id }
        total_line << {
          content: baskets_with_size.sum(&:quantity).to_s,
          width: 25,
          align: :center
        }
      end
      basket_complements.each do |c|
        basket_complement_total =
          all_baskets
            .flat_map(&:baskets_basket_complements)
            .select { |bbc| bbc.basket_complement_id == c.id }
            .sum(&:quantity)
        if show_shop_orders
          basket_complement_total +=
            shop_orders
              .joins(items: { product: :basket_complement })
              .where(shop_products: { basket_complement_id: c.id })
              .sum('shop_order_items.quantity')
              .to_i
        end
        total_line << {
          content: basket_complement_total.to_s,
          width: 25,
          align: :center
        }
      end
      if show_shop_orders
        total_line << {
          content: shop_orders.count.to_s,
          width: 25,
          align: :center
        }
      end
      total_line << {
        content: ::Delivery.human_attribute_name(:signature),
        align: :right,
        width: signature_width
      }
      data << total_line

      # Baskets
      page_baskets.each do |basket|
        column_content = basket.member.name

        if Current.acp.delivery_pdf_show_phones?
          phones = basket.member.phones_array
          if phones.any?
            txt = phones.map(&:phony_formatted).join(', ')
            column_content += "<font size='3'>\n\n</font>"
            column_content += "<font size='10'><i><color rgb='666666'>#{txt}</color></i></font>"
          end
        end

        line = [
          content: column_content,
          width: member_name_width,
          align: :right,
          padding_right: 15,
          font_style: basket.absent? ? :italic : nil,
          text_color: basket.absent? ? '999999' : nil
        ]
        basket_sizes.each do |bs|
          line << (basket.absent? ? '–' : (basket.basket_size_id == bs.id ? display_quantity(basket.quantity) : ''))
        end
        shop_order = shop_orders&.find { |so| so.member_id == basket.membership.member_id }
        basket_complements.each do |c|
          line <<
            if basket.absent?
              '–'
            else
              quantity = basket.baskets_basket_complements.find { |bbc| bbc.basket_complement_id == c.id }&.quantity || 0
              if shop_order
                shop_order_item = shop_order.items.find { |i| i.product.basket_complement_id == c.id }
                quantity += shop_order_item&.quantity || 0
              end
              display_quantity(quantity)
            end
        end
        if show_shop_orders
          line << (shop_order ? 'X' : '')
        end
        line << {
          content: basket.absent? ? Basket.human_attribute_name(:absent).upcase : '',
          width: signature_width,
          align: :center
        }
        data << line
      end

      table(
        data,
        row_colors: %w[FFFFFF DDDDDD],
        cell_style: { border_width: 0.5, border_color: 'AAAAAA', inline_format: true },
        position: :center) do |t|
        t.cells.borders = []
        t.cells.valign = :center if Current.acp.delivery_pdf_show_phones?
        (bs_size + bc_size).times do |i|
          t.columns(1 + i).width = number_width
          t.columns(1 + i).align = :center
          t.columns(1 + i).font_style = :light # Ensure number is well centered in the cell!
          t.columns(1 + i).borders = %i[left right]
        end
        t.row(0).size = 11
        t.row(0).font_style = :bold
        t.row(0).height = 30
        t.row(0).valign = :center
        t.row(0).borders = []
        t.row(-1).borders = %i[left right bottom]
        t.row(-1).columns(0).borders = %i[right bottom]
        t.row(-1).columns(-1).borders = %i[left bottom]
        t.row(-1).border_bottom_width = 0.5
        t.row(-1).border_bottom_color = 'DDDDDD'
      end
    end

    def footer
      bounding_box [20, 80], width: (bounds.width - 40) do
        footer_text = Current.acp.delivery_pdf_footer
        if footer_text.present?
          text_box footer_text,
            at: [0, 0],
            height: 50,
            width: bounds.width,
            valign: :center,
            align: :center,
            size: 11
        end
        text_box "– #{I18n.l(current_time, format: :short)} –",
          at: [0, -60],
          width: bounds.width,
          inline_format: true,
          align: :center,
          size: 8
      end
    end

    def display_quantity(quantity)
      quantity.zero? ? '' : quantity.to_s
    end

    def basket_sizes_for(baskets)
      basket_size_ids =
        baskets.where('baskets.quantity > 0').pluck(:basket_size_id).uniq
      BasketSize.where(id: basket_size_ids)
    end

    def basket_complements_for(baskets, shop_orders)
      complement_ids =
        baskets
          .joins(:baskets_basket_complements)
          .where('baskets_basket_complements.quantity > 0')
          .pluck(:basket_complement_id)
      if shop_orders
        complement_ids +=
          shop_orders
            .joins(:products)
            .pluck('shop_products.basket_complement_id')
      end
      BasketComplement.where(id: complement_ids.uniq)
    end
  end
end
