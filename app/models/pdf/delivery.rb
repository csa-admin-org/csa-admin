# frozen_string_literal: true

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
      @org_logo_io = org_logo_io(size: 110)

      precompute_basket_sums
      precompute_complement_counts
      preload_announcements
      preload_basket_sizes_and_complements

      unless depot
        summary_page
        start_new_page
      end

      @baskets = @baskets.joins(:member).merge(Member.order_by_name)

      depots = Array(depot || @depots)
      depots.each do |depot|
        baskets = @baskets.where(depot: depot)
        shop_orders = @shop_orders.where(depot: depot)
        basket_sizes = basket_sizes_for(baskets)
        member_ids = (baskets.filled.pluck(:member_id) + shop_orders.pluck(:member_id)).uniq
        members_per_page =
          if Current.org.delivery_pdf_member_info == "phones" || depot.delivery_sheets_mode == "home_delivery"
            16
          elsif Current.org.delivery_pdf_member_info == "food_note"
            19
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
        delivery.date.strftime("%Y%m%d")
      ].join("-") + ".pdf"
    end

    private

    def precompute_basket_sums
      @basket_sums_by_depot_and_size =
        @baskets
          .active
          .group(:depot_id, :basket_size_id)
          .sum(:quantity)
      @basket_sums_by_depot =
        @baskets
          .active
          .group(:depot_id)
          .sum(:quantity)
      @basket_sums_by_size =
        @baskets
          .active
          .group(:basket_size_id)
          .sum(:quantity)
      @total_basket_sum = @baskets.active.sum(:quantity)
    end

    def precompute_complement_counts
      @basket_complement_counts_by_depot =
        @baskets
          .active
          .joins(:baskets_basket_complements)
          .group(:depot_id, "baskets_basket_complements.basket_complement_id")
          .sum("baskets_basket_complements.quantity")
      @shop_complement_counts_by_depot =
        @shop_orders
          .joins(items: :product)
          .where.not(shop_products: { basket_complement_id: nil })
          .group(:depot_id, "shop_products.basket_complement_id")
          .sum("shop_order_items.quantity")
      @total_basket_complement_counts =
        @baskets
          .active
          .joins(:baskets_basket_complements)
          .group("baskets_basket_complements.basket_complement_id")
          .sum("baskets_basket_complements.quantity")
      @total_shop_complement_counts =
        @shop_orders
          .joins(items: :product)
          .where.not(shop_products: { basket_complement_id: nil })
          .group("shop_products.basket_complement_id")
          .sum("shop_order_items.quantity")
    end

    def cached_basket_sum(depot_id, basket_size_id)
      @basket_sums_by_depot_and_size[[ depot_id, basket_size_id ]] || 0
    end

    def cached_depot_basket_sum(depot_id)
      @basket_sums_by_depot[depot_id] || 0
    end

    def cached_complement_count(depot_id, complement_id)
      basket_count = @basket_complement_counts_by_depot[[ depot_id, complement_id ]] || 0
      shop_count = @shop_complement_counts_by_depot[[ depot_id, complement_id ]] || 0
      basket_count + shop_count
    end

    def cached_total_complement_count(complement_id)
      basket_count = @total_basket_complement_counts[complement_id] || 0
      shop_count = @total_shop_complement_counts[complement_id] || 0
      basket_count + shop_count
    end

    def preload_announcements
      @announcements_by_depot = {}
      Announcement.deliveries_eq(@delivery.id).each do |announcement|
        announcement.depot_ids.each do |depot_id|
          @announcements_by_depot[depot_id] = announcement
        end
      end
    end

    def announcement_for(depot)
      @announcements_by_depot[depot.id]
    end

    def preload_basket_sizes_and_complements
      basket_size_ids = @baskets.where(quantity: 1..).pluck(:basket_size_id).uniq
      @all_basket_sizes = BasketSize.where(id: basket_size_ids).ordered.to_a

      complement_ids =
        @baskets
          .joins(:baskets_basket_complements)
          .where(baskets_basket_complements: { quantity: 1.. })
          .pluck(:basket_complement_id)
      complement_ids +=
        @shop_orders
          .joins(:products)
          .pluck(shop_products: :basket_complement_id)
      @all_basket_complements = BasketComplement.where(id: complement_ids.uniq).ordered.to_a

      @all_shop_products = @shop_orders.products_displayed_in_delivery_sheets.to_a
    end

    def basket_sizes_for(baskets)
      basket_size_ids = baskets.where(quantity: 1..).pluck(:basket_size_id).uniq
      @all_basket_sizes.select { |bs| basket_size_ids.include?(bs.id) }
    end

    def basket_complements_for(baskets, shop_orders)
      complement_ids = baskets
        .joins(:baskets_basket_complements)
        .where(baskets_basket_complements: { quantity: 1.. })
        .pluck(:basket_complement_id)
      complement_ids += shop_orders
        .joins(:products)
        .pluck(shop_products: :basket_complement_id)
      complement_ids = complement_ids.uniq
      @all_basket_complements.select { |bc| complement_ids.include?(bc.id) }
    end

    def shop_products_for(shop_orders)
      product_ids = shop_orders.joins(:items).pluck(:product_id).uniq
      @all_shop_products.select { |p| product_ids.include?(p.id) }
    end

    def org_logo
      StringIO.new(@org_logo_io.string)
    end

    def summary_page
      summary_header
      summary_content
      delivery_note
    end

    def summary_header
      image org_logo, at: [ 15, bounds.height - 20 ], width: 110
      bounding_box [ bounds.width - 370, bounds.height - 20 ], width: 350, height: 120 do
        text I18n.t("delivery.summary"), size: 24, align: :right
        move_down 5
        text I18n.l(delivery.date), size: 24, align: :right
      end
    end

    def summary_content
      basket_sizes = BasketSize.for(@baskets)
      basket_complements = BasketComplement.for(@baskets, @shop_orders)
      shop_products = @shop_orders.products_displayed_in_delivery_sheets

      font_size 9
      move_down 1.cm

      bs_size = basket_sizes.size + 1
      bc_size = basket_complements.size
      sp_size = 0
      sp_size += 1 if @shop_orders.any?
      sp_size += shop_products.size

      page_border = 65
      width = bounds.width - 2 * page_border
      number_width = 25
      depot_name_width = width - (bs_size + bc_size + sp_size) * number_width
      total_rotate = 45
      offset_x = 8
      offset_y = 12

      # Headers Basket Sizes and Complements
      header_index = 0
      bounding_box [ page_border, cursor ], width: width, height: 25, position: :bottom do
        text_box "", width: depot_name_width, at: [ 0, cursor ]
        bs_names = basket_sizes.map(&:public_name)
        bs_names << I18n.t("delivery.basket_sizes_total")
        bs_names.each_with_index do |name, i|
          fill_color header_index.even? ? "666666" : "000000"
          text_box name,
            rotate: total_rotate,
            at: [ depot_name_width + i * number_width + offset_x, cursor + offset_y ],
            valign: :center,
            size: name == bs_names.last ? 9 : 8,
            style: :bold,
            width: 150
          header_index += 1
        end
        basket_complements.each_with_index do |bc, i|
          fill_color header_index.even? ? "666666" : "000000"
          text_box bc.public_name,
            rotate: total_rotate,
            at: [ depot_name_width + (bs_size + i) * number_width + offset_x, cursor + offset_y ],
            valign: :center,
            overflow: :expand,
            size: 8,
            style: :bold,
            width: 150
          header_index += 1
        end
        if @shop_orders.any?
          fill_color header_index.even? ? "666666" : "000000"
          text_box I18n.t("shop.title_orders", count: 1),
            rotate: total_rotate,
            at: [ depot_name_width + (bs_size + bc_size) * number_width + offset_x, cursor + offset_y ],
            valign: :center,
            size: 8,
            style: :bold,
            width: 100
          header_index += 1
        end
        shop_products.each_with_index do |product, i|
          fill_color header_index.even? ? "666666" : "000000"
          text_box product.name_with_single_variant,
            rotate: total_rotate,
            at: [ depot_name_width + (bs_size + bc_size + 1 + i) * number_width + offset_x, cursor + offset_y ],
            valign: :center,
            size: 8,
            style: :bold,
            width: 100
          header_index += 1
        end
      end
      fill_color "000000"

      move_up 0.4.cm
      data = []

      # Totals
      total_line = [
        content: Depot.model_name.human,
        width: depot_name_width,
        align: :right
      ]
      basket_sizes.each do |bs|
        total_line << {
          content: (@basket_sums_by_size[bs.id] || 0).to_s,
          width: number_width,
          align: :center
        }
      end
      total_line << {
        content: @total_basket_sum.to_s,
        width: number_width,
        align: :center
      }
      basket_complements.each do |c|
        total_line << {
          content: cached_total_complement_count(c.id).to_s,
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
      shop_products.each do |p|
        total_line << {
          content: @shop_orders.quantity_for(p).to_s,
          width: number_width,
          align: :center
        }
      end
      data << total_line

      # Depots
      @depots.each do |depot|
        data << summary_baskets_line(depot, width: depot_name_width, basket_sizes: basket_sizes, basket_complements: basket_complements, shop_products: shop_products)
      end

      if @depots.any?(&:free?) && @depots.any?(&:paid?)
        data << [ "" ]
        data << summary_baskets_line(@depots.free, title: t("free_depots"), width: depot_name_width, basket_sizes: basket_sizes, basket_complements: basket_complements, shop_products: shop_products)
        data << summary_baskets_line(@depots.paid, title: t("paid_depots"), width: depot_name_width, basket_sizes: basket_sizes, basket_complements: basket_complements, shop_products: shop_products)
      end

      cell_style =
        case @depots.size
        when 1..30
          { size: 10, height: 18, padding: 3 }
        when 30..37
          { size: 10, height: 16, padding: 2 }
        else
          { size: 9, height: 12, padding: 0.5 }
        end

      table(
        data,
        row_colors: %w[DDDDDD FFFFFF],
        cell_style: {
          border_width: 0,
          border_color: "FFFFFF",
          inline_format: true
        }.merge(cell_style),
        position: :center) do |t|
        t.cells.borders = []

        (bs_size + bc_size + sp_size).times do |i|
          t.column(1 + i).width = number_width
          t.column(1 + i).align = :center
          t.column(1 + i).font_style = :light # Ensure number is well centered in the cell!
        end
        t.column(bs_size).font_style = :bold
        t.column(bs_size).padding_top = cell_style[:padding] + 1  # Ensure number is well centered in the cell!
        t.column(0).padding_top = cell_style[:padding] + 1  # Ensure number is well centered in the cell!

        t.row(0).height = 22
        t.row(0).size = 10
        t.row(0).font_style = :bold
        t.row(0).padding = [ 6, 2, 6, 2 ]
        t.row(0).background_color = "FFFFFF"

        t.column(0).padding_right = 10

        t.cells.column_count.times do |i|
          if i%2 == 1
            t.column(i).background_color = "CCCCCC"
          end
        end

        if t.cells.row_count%2 == 0
          t.row(-1).borders = %i[bottom right]
          t.row(-1).border_bottom_width = 1
          t.row(-1).border_bottom_color = "CCCCCC"
        end
        if t.cells.column_count%2 == 1
          t.column(-1).borders = %i[bottom right]
          t.column(-1).border_right_width = 1
          t.column(-1).border_right_color = "CCCCCC"
        end

        t.row(0).borders = %i[bottom right]
        t.row(0).border_bottom_width = 1
        t.row(0).border_bottom_color = "000000"

        t.column(bs_size).background_color = "999999"

        if @depots.any?(&:free?) && @depots.any?(&:paid?)

          if t.cells.row_count%2 == 1
            t.row(-4).borders = %i[bottom right]
            t.row(-4).border_bottom_width = 1
            t.row(-4).border_bottom_color = "CCCCCC"
          end
          if t.cells.column_count%2 == 0
            t.column(-4).borders = %i[bottom right]
            t.column(-4).border_right_width = 1
            t.column(-4).border_right_color = "CCCCCC"
          end

          if t.cells.row_count%2 == 1
            t.row(-2).borders = %i[top right]
            t.row(-2).border_top_width = 1
            t.row(-2).border_top_color = "CCCCCC"
          end
          if t.cells.column_count%2 == 0
            t.column(-2).borders = %i[top right]
            t.column(-2).border_right_width = 1
            t.column(-2).border_right_color = "CCCCCC"
          end

          t.row(0).borders = %i[bottom right]
          t.row(0).border_bottom_width = 1
          t.row(0).border_bottom_color = "000000"

          t.row(-3).height = cell_style[:height] + 4
          t.row(-3).background_color = "FFFFFF"
        end
      end
    end

    def summary_baskets_line(depot, title: nil, width:, basket_sizes:, basket_complements:, shop_products:)
      column_content = title || depot.name
      depot_ids = depot.respond_to?(:ids) ? depot.ids : [ depot.id ]
      shop_orders = @shop_orders.where(depot_id: depot_ids)

      line = [
        content: column_content,
        width: width,
        align: :right
      ]
      basket_sizes.each do |bs|
        sum = depot_ids.sum { |depot_id| cached_basket_sum(depot_id, bs.id) }
        line << display_quantity(sum)
      end
      total = depot_ids.sum { |depot_id| cached_depot_basket_sum(depot_id) }
      line << display_quantity(total)
      basket_complements.each do |c|
        count = depot_ids.sum { |depot_id| cached_complement_count(depot_id, c.id) }
        line << display_quantity(count)
      end
      if @shop_orders.any?
        line << display_quantity(shop_orders.count)
      end
      shop_products.each do |p|
        line << display_quantity(shop_orders.quantity_for(p))
      end
      line
    end

    def delivery_note
      return unless delivery.note?

      move_down 1.cm
      box_border = 70
      bg_color = "FFEDD5"
      padding = 5

      text = delivery.note.truncate(300)
      text_color = "9A3413"
      text_options = {
        size: 10,
        leading: 4,
        valign: :center,
        align: :center
      }

      box_height = height_of_formatted([ text: text ], text_options)

      bounding_box [ box_border, cursor ], width: (bounds.width - 2*box_border), height: box_height + padding do
        fill_color   bg_color
        stroke_color bg_color
        fill_and_stroke_rounded_rectangle(
          [ bounds.left - padding, cursor ],
          bounds.left + bounds.right + padding*2,
          box_height + padding*2,
          padding)
        fill_color   text_color
        stroke_color text_color

        pad padding do
          formatted_text([ text: text ], text_options)
        end
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
      image org_logo, at: [ 15, bounds.height - 20 ], width: 110
      if announcement = announcement_for(depot)
        bounding_box [ 20, bounds.height - 130 ], width: 290, height: 70 do
          text announcement.text,
            size: 13,
            style: :bold,
            leading: 4,
            valign: :center
        end
      end
      bounding_box [ bounds.width - 370, bounds.height - 20 ], width: 350, height: 120 do
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
      shop_products = shop_products_for(shop_orders)

      font_size 11
      move_down 2.cm

      bs_size = basket_sizes.size
      bc_size = basket_complements.size
      sp_size = 0
      sp_size += 1 if shop_orders.any?
      sp_size += shop_products.size

      page_border = 20
      width = bounds.width - 2 * page_border
      number_width = 25
      extra_width = 110
      member_name_width = width - (bs_size + bc_size + sp_size) * number_width - extra_width
      address_width = depot.delivery_sheets_mode == "home_delivery" ? (member_name_width / 2) : 0
      offset_x = 6
      offset_y = 12

      # Headers Basket Sizes and Complements
      numbers_width_offset = member_name_width
      header_index = 0
      bounding_box [ page_border, cursor ], width: width, height: 25, position: :bottom do
        text_box "", width: numbers_width_offset, at: [ 0, cursor ]
        basket_sizes.each_with_index do |bs, i|
          fill_color header_index.even? ? "666666" : "000000"
          text_box bs.public_name,
            rotate: 45,
            at: [ numbers_width_offset + i * number_width + offset_x, cursor + offset_y ],
            valign: :center,
            size: 10,
            style: :bold,
            width: 150
          header_index += 1
        end
        basket_complements.each_with_index do |bc, i|
          fill_color header_index.even? ? "666666" : "000000"
          text_box bc.public_name,
            rotate: 45,
            at: [ numbers_width_offset + (bs_size + i) * number_width + offset_x, cursor + offset_y ],
            valign: :center,
            overflow: :expand,
            size: 10,
            style: :bold,
            width: 150
          header_index += 1
        end
        if shop_orders.any?
          fill_color header_index.even? ? "666666" : "000000"
          text_box I18n.t("shop.title_orders", count: 1),
            rotate: 45,
            at: [ numbers_width_offset + (bs_size + bc_size) * number_width + offset_x, cursor + offset_y ],
            valign: :center,
            size: 10,
            style: :bold,
            width: 150
          header_index += 1
        end
        shop_products.each_with_index do |product, i|
          fill_color header_index.even? ? "666666" : "000000"
          text_box product.name_with_single_variant,
            rotate: 45,
            at: [ numbers_width_offset + (bs_size + bc_size + 1 + i) * number_width + offset_x, cursor + offset_y ],
            valign: :center,
            overflow: :expand,
            size: 10,
            style: :bold,
            width: 150
          header_index += 1
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
        align: depot.delivery_sheets_mode == "home_delivery" ? :left : :right
      ]
      if depot.delivery_sheets_mode == "home_delivery"
        total_line << {
          content: ::Delivery.human_attribute_name(:address),
          width: address_width,
          align: :left
        }
      end
      basket_sizes.each do |bs|
        total_line << {
          content: cached_basket_sum(depot.id, bs.id).to_s,
          width: number_width,
          align: :center
        }
      end
      basket_complements.each do |c|
        total_line << {
          content: cached_complement_count(depot.id, c.id).to_s,
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
      shop_products.each do |p|
        total_line << {
          content: shop_orders.quantity_for(p).to_s,
          width: number_width,
          align: :center
        }
      end
      extra_content =
        case depot.delivery_sheets_mode
        when "signature"; ::Delivery.human_attribute_name(:signature)
        when "home_delivery"; ::Member.human_attribute_name(:note)
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

        case Current.org.delivery_pdf_member_info
        when "phones"
          phones = member.phones_array
          if phones.any?
            info_txt = phones.map { |p| display_phone(p) }.join(", ")
          end
        when "food_note"
          if member.food_note?
            info_txt = member.food_note.truncate(90)
          end
        end
        if info_txt
          column_content += "<font size='3'>\n\n</font>"
          column_content += "<font size='9'><i><color rgb='777777'>#{info_txt}</color></i></font>"
        end

        line = [
          content: column_content,
          width: (member_name_width - address_width),
          align: depot.delivery_sheets_mode == "home_delivery" ? :left : :right,
          size: depot.delivery_sheets_mode == "home_delivery" ? 11 : 12,
          padding: [ 4, 5, 8, 5 ],
          font_style: basket&.absent? ? :italic : nil,
          text_color: basket&.absent? ? "999999" : nil
        ]
        if depot.delivery_sheets_mode == "home_delivery"
          content = <<~TEXT
            <font size='10'>#{member.street}\n#{member.zip} #{member.city}</font>
          TEXT
          line << {
            content: content,
            align: :left,
            valign: :center,
            width: address_width,
            padding_top: 1,
            font_style: basket&.absent? ? :italic : nil,
            text_color: basket&.absent? ? "999999" : nil
          }
        end
        basket_sizes.each do |bs|
          content = (basket && basket.basket_size_id == bs.id) ? display_quantity(basket.quantity) : ""
          line << counter_line(content, basket)
        end
        basket_complements.each do |c|
          quantity = basket&.baskets_basket_complements&.find { |bbc| bbc.basket_complement_id == c.id }&.quantity || 0
          if shop_order
            shop_order_item = shop_order.items.find { |i| i.product.basket_complement_id == c.id }
            quantity += shop_order_item&.quantity || 0
          end
          content = display_quantity(quantity)
          line << counter_line(content, basket)
        end
        if shop_orders.any?
          content =
            if basket&.absent?
              "–"
            else
              shop_order ? "X" : ""
            end
          line << counter_line(content, basket)
        end
        shop_products.each do |p|
          content =
            if basket&.absent?
              "–"
            elsif shop_order
              shop_order_item = shop_order.items.find { |i| i.product_id == p.id }
              display_quantity(shop_order_item&.quantity || 0)
            else
              ""
            end
          line << counter_line(content, basket)
        end
        extra_content =
          if basket&.absent?
            Basket.human_attribute_name(:absent).upcase
          elsif depot.delivery_sheets_mode == "home_delivery"
            member.delivery_note
          else
            ""
          end
        line << {
          content: extra_content,
          width: extra_width,
          align: :right,
          valign: :center,
          size: depot.delivery_sheets_mode == "home_delivery" ? 9 : 10,
          padding_top: depot.delivery_sheets_mode == "home_delivery" ? 1 : 2,
          font_style: (depot.delivery_sheets_mode == "home_delivery" || basket&.absent?) ? :italic : nil,
          text_color: basket&.absent? ? "999999" : nil
        }
        data << line
      end

      table(
        data,
        row_colors: %w[DDDDDD FFFFFF],
        cell_style: { border_width: 0, border_color: "FFFFFF", inline_format: true, valign: :center },
        position: :center) do |t|
        t.cells.borders = []

        numbers_column_offset = depot.delivery_sheets_mode == "home_delivery" ? 2 : 1
        (bs_size + bc_size + sp_size).times do |i|
          t.column(numbers_column_offset + i).width = number_width
        end

        t.row(0).size = 11
        t.row(0).font_style = :bold
        t.row(0).padding = [ 4, 5, 8, 5 ]
        t.row(0).valign = :center
        t.row(0).background_color = "FFFFFF"

        t.column(0).padding_right = 10

        colors_offset = depot.delivery_sheets_mode == "home_delivery" ? 1 : 0
        t.cells.column_count.times do |i|
         if i%2 == 1 && i != (t.cells.column_count - 1 - colors_offset)
           t.column(i + colors_offset).background_color = "CCCCCC"
         end
        end
        if t.cells.row_count%2 == 0
          t.row(-1).borders = %i[bottom left]
          t.row(-1).border_bottom_width = 1
          t.row(-1).border_bottom_color = "CCCCCC"
        end
        if t.cells.column_count%2 == colors_offset
          t.column(-1).borders = %i[bottom left]
          t.column(-1).border_left_width = 1
          t.column(-1).border_left_color = "CCCCCC"
        end

        t.row(0).borders = %i[bottom left]
        t.row(0).border_bottom_width = 1
        t.row(0).border_bottom_color = "000000"
      end
    end

    def counter_line(content, basket)
      line = {
        content: content,
        align: :center,
        padding_top: 1
      }
      if basket&.absent?
        line[:font_style] = :italic
        line[:text_color] = "999999"
        line[:padding_top] = 2
        line[:padding_left] = 0
      end
      line
    end

    def footer
      bounding_box [ 20, 80 ], width: (bounds.width - 40) do
        footer_text = Current.org.delivery_pdf_footer
        if footer_text.present?
          text_box footer_text,
            at: [ 0, 0 ],
            height: 50,
            width: bounds.width,
            valign: :center,
            align: :center,
            size: 11
        end
        text_box "– #{I18n.l(current_time, format: :short)} –",
          at: [ 0, -60 ],
          width: bounds.width,
          inline_format: true,
          align: :center,
          size: 8
      end
    end

    def t(key, *args)
      I18n.t("delivery.#{key}", *args)
    end

    def display_quantity(quantity)
      quantity.zero? ? "" : quantity.to_s
    end
  end
end
