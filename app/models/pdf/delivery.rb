module PDF
  class Delivery < Base
    attr_reader :delivery, :current_time

    def initialize(delivery, depot = nil)
      @delivery = delivery
      super
      @current_time = Time.current
      @baskets = delivery.baskets
      @shop_orders = @delivery.shop_orders.all_without_cart
      @depots = Depot.where(id: (@baskets.pluck(:depot_id) + @shop_orders.pluck(:depot_id)).uniq)

      unless depot
        summary_page
        start_new_page
      end

      @baskets = @baskets.joins(:member).order('members.name')

      depots = Array(depot || @depots)
      depots.each do |depot|
        baskets = @baskets.where(depot: depot)
        if depot.delivery_sheets_mode == 'home_delivery'
          baskets = baskets.not_absent
        end
        shop_orders = @shop_orders.where(depot: depot)
        basket_sizes = basket_sizes_for(baskets)
        member_ids = (baskets.not_empty.pluck(:member_id) + shop_orders.pluck(:member_id)).uniq
        members_per_page =
          if Current.acp.delivery_pdf_show_phones? || depot.delivery_sheets_mode == 'home_delivery'
            16
          else
            22
          end
        total_pages = (member_ids.count / members_per_page.to_f).ceil
        members = Member.where(id: member_ids).sort_by { |m| depot.member_sorting(m) }
        members.each_slice(members_per_page).with_index do |slice, i|
          page_n = i + 1
          page(depot, slice, baskets, basket_sizes, shop_orders, page: page_n, total_pages: total_pages)
          start_new_page unless page_n == total_pages
        end
        start_new_page unless depots.last == depot
      end
    end

    def filename
      [
        ::Delivery.human_attribute_name(:sheets).parameterize,
        ::Delivery.model_name.human.parameterize,
        delivery.display_number,
        delivery.date.strftime('%Y%m%d')
      ].join('-') + '.pdf'
    end

    private

    def summary_page
      summary_header
      summary_content
    end

    def summary_header
      image acp_logo_io, at: [15, bounds.height - 20], width: 110
      bounding_box [bounds.width - 370, bounds.height - 20], width: 350, height: 120 do
        text I18n.t('delivery.summary'), size: 24, align: :right
        move_down 5
        text I18n.l(delivery.date), size: 24, align: :right
      end
    end

    def summary_content
      basket_sizes = basket_sizes_for(@baskets)
      basket_complements = basket_complements_for(@baskets, @shop_orders)

      font_size 9
      move_down 1.cm

      bs_size = basket_sizes.size
      bc_size = basket_complements.size
      bc_size += 1 if @shop_orders.any?

      page_border = 65
      width = bounds.width - 2 * page_border
      number_width = 25
      depot_name_width = width - (bs_size + bc_size) * number_width
      total_rotate = 45
      offset_x = 8
      offset_y = 12

      # Headers Basket Sizes and Complements
      header_index = 0
      bounding_box [page_border, cursor], width: width, height: 25, position: :bottom do
        text_box '', width: depot_name_width, at: [0, cursor]
        basket_sizes.each_with_index do |bs, i|
          fill_color header_index.even? ? '999999' : '000000'
          text_box bs.public_name,
            rotate: total_rotate,
            at: [depot_name_width + i * number_width + offset_x, cursor + offset_y],
            valign: :center,
            size: 8,
            style: :bold,
            width: 150
          header_index += 1
        end
        basket_complements.each_with_index do |bc, i|
          fill_color header_index.even? ? '999999' : '000000'
          text_box bc.public_name,
            rotate: total_rotate,
            at: [depot_name_width + (bs_size + i) * number_width + offset_x, cursor + offset_y],
            valign: :center,
            overflow: :expand,
            size: 8,
            style: :bold,
            width: 150
          header_index += 1
        end
        if @shop_orders.any?
          fill_color header_index.even? ? '999999' : '000000'
          text_box I18n.t('shop.title_orders', count: 1),
            rotate: total_rotate,
            at: [depot_name_width + (bs_size + bc_size - 1) * number_width + offset_x, cursor + offset_y],
            valign: :center,
            size: 8,
            style: :bold,
            width: 100
          header_index += 1
        end
      end
      fill_color '000000'

      move_up 0.4.cm
      data = []

      # Totals
      total_line = [
        content: Depot.model_name.human,
        width: depot_name_width,
        align: :right
      ]
      all_baskets = @baskets.not_absent
      basket_sizes.each do |bs|
        total_line << {
          content: all_baskets.where(basket_size: bs).sum(:quantity).to_s,
          width: number_width,
          align: :center
        }
      end
      basket_complements.each do |c|
        total_line << {
          content: (all_baskets.complement_count(c) + @shop_orders.complement_count(c)).to_s,
          width: number_width,
          align: :center
        }
      end
      if @shop_orders.any?
        total_line << {
          content: @shop_orders.count.to_s,
          width: number_width,
          align: :center
        }
      end
      data << total_line

      # Depots
      @depots.each do |depot|
        column_content = depot.name
        baskets = @baskets.not_absent.where(depot: depot)
        shop_orders = @shop_orders.where(depot: depot)

        line = [
          content: column_content,
          width: depot_name_width,
          align: :right
        ]
        basket_sizes.each do |bs|
          line << display_quantity(baskets.where(basket_size: bs).sum(:quantity))
        end
        basket_complements.each do |c|
          line << display_quantity(baskets.complement_count(c) + shop_orders.complement_count(c))
        end
        if @shop_orders.any?
          line << display_quantity(shop_orders.count)
        end
        data << line
      end

      cell_style =
        case @depots.size
        when 1..30
          { size: 10, height: 18, padding: 3 }
        when 30..37
          { size: 10, height: 16, padding: 2 }
        else
          { size: 9, height: 12, padding: 1 }
        end

      table(
        data,
        row_colors: %w[DDDDDD FFFFFF],
        cell_style: {
          border_width: 0,
          border_color: 'FFFFFF',
          inline_format: true,
        }.merge(cell_style),
        position: :center) do |t|
        t.cells.borders = []

        (bs_size + bc_size).times do |i|
          t.column(1 + i).width = number_width
          t.column(1 + i).align = :center
          t.column(1 + i).font_style = :light # Ensure number is well centered in the cell!
        end

        t.row(0).height = 22
        t.row(0).size = 10
        t.row(0).font_style = :bold
        t.row(0).padding = [6, 2, 6, 2]
        t.row(0).background_color = 'FFFFFF'

        t.column(0).padding_right = 10

        t.cells.column_count.times do |i|
         if i%2 == 1
           t.column(i).background_color = 'CCCCCC'
         end
        end
        if t.cells.row_count%2 == 0
          t.row(-1).borders = %i[bottom left]
          t.row(-1).border_bottom_width = 1
          t.row(-1).border_bottom_color = 'CCCCCC'
        end

        t.row(0).borders = %i[bottom right]
        t.row(0).border_bottom_width = 1
        t.row(0).border_bottom_color = '000000'
      end
    end

    def info
      super.merge(Title: "#{::Delivery.human_attribute_name(:sheets)} #{delivery.date}")
    end

    def page(depot, members, baskets, basket_sizes, shop_orders, page:, total_pages:)
      header(depot, page: page, total_pages: total_pages)
      content(depot, members, baskets, basket_sizes, shop_orders)
      footer
    end

    def header(depot, page:, total_pages:)
      image acp_logo_io, at: [15, bounds.height - 20], width: 110
      if announcement = Announcement.for(delivery, depot)
        bounding_box [20, bounds.height - 130], width: 290, height: 70 do
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

    def content(depot, members, baskets, basket_sizes, shop_orders)
      basket_complements = basket_complements_for(baskets, shop_orders)

      font_size 11
      move_down 2.cm

      bs_size = basket_sizes.size
      bc_size = basket_complements.size
      bc_size += 1 if shop_orders.any?

      page_border = 20
      width = bounds.width - 2 * page_border
      number_width = 25
      extra_width = 110
      member_name_width = width - (bs_size + bc_size) * number_width - extra_width
      address_width = depot.delivery_sheets_mode == 'home_delivery' ? (member_name_width / 2) : 0
      offset_x = 6
      offset_y = 12

      # Headers Basket Sizes and Complements
      numbers_width_offset = member_name_width
      header_index = 0
      bounding_box [page_border, cursor], width: width, height: 25, position: :bottom do
        text_box '', width: numbers_width_offset, at: [0, cursor]
        basket_sizes.each_with_index do |bs, i|
          fill_color header_index.even? ? '999999' : '000000'
          text_box bs.public_name,
            rotate: 45,
            at: [numbers_width_offset + i * number_width + offset_x, cursor + offset_y],
            valign: :center,
            size: 10,
            style: :bold,
            width: 150
          header_index += 1
        end
        basket_complements.each_with_index do |bc, i|
          fill_color header_index.even? ? '999999' : '000000'
          text_box bc.public_name,
            rotate: 45,
            at: [numbers_width_offset + (bs_size + i) * number_width + offset_x, cursor + offset_y],
            valign: :center,
            overflow: :expand,
            size: 10,
            style: :bold,
            width: 150
          header_index += 1
        end
        if shop_orders.any?
          fill_color header_index.even? ? '999999' : '000000'
          text_box I18n.t('shop.title_orders', count: 1),
            rotate: 45,
            at: [numbers_width_offset + (bs_size + bc_size - 1) * number_width + offset_x, cursor + offset_y],
            valign: :center,
            size: 10,
            style: :bold,
            width: 100
        end
      end
      fill_color "000000"

      move_up 0.4.cm
      font_size 12
      data = []

      # Depot Totals
      total_line = [
        content: Member.model_name.human,
        width: (member_name_width - address_width),
        height: 28,
        align: depot.delivery_sheets_mode == 'home_delivery' ? :left : :right
      ]
      if depot.delivery_sheets_mode == 'home_delivery'
        total_line << {
          content: ::Delivery.human_attribute_name(:address),
          width: address_width,
          align: :left
        }
      end
      all_baskets = baskets.not_absent
      basket_sizes.each do |bs|
        total_line << {
          content: all_baskets.where(basket_size: bs).sum(:quantity).to_s,
          width: number_width,
          align: :center
        }
      end
      basket_complements.each do |c|
        total_line << {
          content: (all_baskets.complement_count(c) + shop_orders.complement_count(c)).to_s,
          width: number_width,
          align: :center
        }
      end
      if shop_orders.any?
        total_line << {
          content: shop_orders.count.to_s,
          width: number_width,
          align: :center
        }
      end
      extra_content =
        case depot.delivery_sheets_mode
        when 'signature'; ::Delivery.human_attribute_name(:signature)
        when 'home_delivery'; ::Member.human_attribute_name(:note)
        end
      total_line << {
        content: extra_content,
        align: :right,
        width: extra_width
      }
      data << total_line

      # Members
      baskets = baskets.includes(:membership, :baskets_basket_complements).to_a
      shop_orders = shop_orders.includes(items: :product).to_a
      members.each do |member|
        column_content = member.name
        basket = baskets.find { |b| b.membership.member_id == member.id }
        shop_order = shop_orders.find { |so| so.member_id == member.id }

        if Current.acp.delivery_pdf_show_phones?
          phones = member.phones_array
          if phones.any?
            txt = phones.map { |p| display_phone(p) }.join(', ')
            column_content += "<font size='3'>\n\n</font>"
            column_content += "<font size='9'><i><color rgb='777777'>#{txt}</color></i></font>"
          end
        end

        line = [
          content: column_content,
          width: (member_name_width - address_width),
          align: depot.delivery_sheets_mode == 'home_delivery' ? :left : :right,
          size: depot.delivery_sheets_mode == 'home_delivery' ? 11 : 12,
          padding: [4, 5, 8, 5],
          font_style: basket&.absent? ? :italic : nil,
          text_color: basket&.absent? ? '999999' : nil
        ]
        if depot.delivery_sheets_mode == 'home_delivery'
          content = <<~TEXT
            <font size='10'>#{member.final_delivery_address}\n#{member.final_delivery_zip} #{member.final_delivery_city}</font>
          TEXT
          line << {
            content: content,
            align: :left,
            valign: :center,
            width: address_width,
            padding_top: 1
          }
        end
        basket_sizes.each do |bs|
          line <<
            if basket&.absent?
              '–'
            else
              basket && basket.basket_size_id == bs.id ? display_quantity(basket.quantity) : ''
            end
        end
        basket_complements.each do |c|
          line <<
            if basket&.absent?
              '–'
            else
              quantity = basket&.baskets_basket_complements&.find { |bbc| bbc.basket_complement_id == c.id }&.quantity || 0
              if shop_order
                shop_order_item = shop_order.items.find { |i| i.product.basket_complement_id == c.id }
                quantity += shop_order_item&.quantity || 0
              end
              display_quantity(quantity)
            end
        end
        if shop_orders.any?
          line <<
            if basket&.absent?
              '–'
            else
              shop_order ? 'X' : ''
            end
        end
        extra_content =
          case depot.delivery_sheets_mode
          when 'signature'; basket&.absent? ? Basket.human_attribute_name(:absent).upcase : ''
          when 'home_delivery'; member.delivery_note
          end
        line << {
          content: extra_content,
          width: extra_width,
          align: :right,
          valign: :center,
          size: 9,
          font_style: depot.delivery_sheets_mode == 'home_delivery' ? :italic : nil,
          padding_top: 1
        }
        data << line
      end

      table(
        data,
        row_colors: %w[DDDDDD FFFFFF],
        cell_style: { border_width: 0, border_color: 'FFFFFF', inline_format: true, valign: :center },
        position: :center) do |t|
        t.cells.borders = []

        numbers_column_offset = depot.delivery_sheets_mode == 'home_delivery' ? 2 : 1
        (bs_size + bc_size).times do |i|
          t.column(numbers_column_offset + i).width = number_width
          t.column(numbers_column_offset + i).align = :center
          # if Current.acp.delivery_pdf_show_phones? || depot.delivery_sheets_mode == 'home_delivery'
            t.column(numbers_column_offset + i).padding_top = -1
          # end
          t.column(numbers_column_offset + i).font_style = :light # Ensure number is well centered in the cell!
        end

        t.row(0).size = 11
        t.row(0).font_style = :bold
        t.row(0).padding = [4, 5, 8, 5]
        t.row(0).valign = :center
        t.row(0).background_color = 'FFFFFF'

        t.column(0).padding_right = 10

        colors_offset = depot.delivery_sheets_mode == 'home_delivery' ? 1 : 0
        t.cells.column_count.times do |i|
         if i%2 == 1 && i != (t.cells.column_count - 1 - colors_offset)
           t.column(i + colors_offset).background_color = 'CCCCCC'
         end
        end
        if t.cells.row_count%2 == 0
          t.row(-1).borders = %i[bottom left]
          t.row(-1).border_bottom_width = 1
          t.row(-1).border_bottom_color = 'CCCCCC'
        end
        if t.cells.column_count%2 == colors_offset
          t.column(-1).borders = %i[bottom left]
          t.column(-1).border_left_width = 1
          t.column(-1).border_left_color = 'CCCCCC'
        end

        t.row(0).borders = %i[bottom left]
        t.row(0).border_bottom_width = 1
        t.row(0).border_bottom_color = '000000'
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
      complement_ids +=
        shop_orders
          .joins(:products)
          .pluck('shop_products.basket_complement_id')
      BasketComplement.where(id: complement_ids.uniq)
    end
  end
end
