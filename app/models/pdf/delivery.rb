# frozen_string_literal: true

module PDF
  class Delivery < Base
    include ActionView::Helpers::NumberHelper
    include ApplicationHelper
    include NumbersHelper

    PAGE_WIDTH = 595.28
    PAGE_HEIGHT = 841.89

    RotatedHeader = Data.define(:label, :left, :width, :color, :font_size)
    Column = Data.define(:width, :align, :shaded, :total, :bold)
    SummarySection = Data.define(:rows, :has_bottom_rule)
    SummaryTable = Data.define(
      :width,
      :depot_name_width,
      :tier,
      :has_right_rule,
      :rotated_headers,
      :columns,
      :header_values,
      :main_section,
      :extra_sections
    )
    BasketContentCell = Data.define(:text, :align)
    BasketContentTable = Data.define(
      :page_border,
      :width,
      :tier,
      :variant,
      :has_right_rule,
      :has_bottom_rule,
      :rotated_headers,
      :columns,
      :header_cells,
      :rows
    )
    SummaryPage = Data.define(:summary_table, :basket_content_table, :delivery_note)
    ChangesGroup = Data.define(:depot_name, :entries)
    ChangesEntry = Data.define(:member_name, :dimmed, :changes)
    DepotHeaderCell = Data.define(:text, :align, :shaded, :left_border)
    DepotCounterCell = Data.define(:text, :shaded, :absent)
    DepotMemberRow = Data.define(
      :name,
      :info,
      :absent,
      :address_lines,
      :address_overlay,
      :counters,
      :extra_text,
      :extra_overlay
    )
    DepotSheetTable = Data.define(
      :width,
      :name_col_width,
      :address_col_width,
      :home_delivery,
      :show_last_col_left_border,
      :has_bottom_rule,
      :rotated_headers,
      :column_widths,
      :header_cells,
      :rows
    )
    DepotPage = Data.define(:depot_name, :announcement, :page, :total_pages, :sheet_table, :basket_content_table)

    attr_reader :delivery, :current_time

    def initialize(delivery, depot = nil)
      @delivery = delivery
      @target_depot = depot
      @current_time = Time.current
      @baskets = delivery.baskets
      @shop_orders = @delivery.shop_orders.all_without_cart
      @depots = Depot.where(id: (@baskets.pluck(:depot_id) + @shop_orders.pluck(:depot_id)).uniq)

      precompute_basket_sums
      precompute_complement_counts
      preload_announcements
      preload_home_delivery_addresses
      preload_basket_sizes_and_complements
      preload_basket_contents
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

    def template_path
      "pdfs/deliveries/show"
    end

    def stylesheets
      %w[pdf/delivery]
    end

    def title
      "#{::Delivery.human_attribute_name(:sheets)} #{delivery.date}"
    end

    def creation_date
      current_time
    end

    def view_assigns
      {
        logo_data_uri: org_logo_data_uri(size: 110),
        delivery_date: I18n.l(delivery.date),
        footer_text: Current.org.delivery_pdf_footer.presence,
        generated_at_label: "– #{I18n.l(current_time, format: :short)} –",
        summary_pages: @target_depot ? [] : build_summary_pages,
        changes_groups: @target_depot ? [] : build_changes_groups,
        depot_pages: build_depot_pages
      }
    end

    def precompute_basket_sums
      counted = counted_baskets
      @basket_sums_by_depot_and_size =
        counted.group(:depot_id, :basket_size_id).sum(:quantity)
      @basket_sums_by_depot =
        counted.group(:depot_id).sum(:quantity)
      @basket_sums_by_size =
        counted.group(:basket_size_id).sum(:quantity)
      @total_basket_sum = counted.sum(:quantity)
      @content_basket_sums_by_depot_and_size =
        if Current.org.delivery_basket_count_scope == :active
          @basket_sums_by_depot_and_size
        else
          @baskets.active.group(:depot_id, :basket_size_id).sum(:quantity)
        end
    end

    def counted_baskets
      @baskets.send(Current.org.delivery_basket_count_scope)
    end

    def precompute_complement_counts
      @basket_complement_counts_by_depot =
        counted_baskets
          .joins(:baskets_basket_complements)
          .group(:depot_id, "baskets_basket_complements.basket_complement_id")
          .sum("baskets_basket_complements.quantity")
      @shop_complement_counts_by_depot =
        @shop_orders
          .joins(items: :product_variant)
          .where.not(shop_product_variants: { basket_complement_id: nil })
          .group(:depot_id, "shop_product_variants.basket_complement_id")
          .sum("shop_order_items.quantity")
      @total_basket_complement_counts =
        counted_baskets
          .joins(:baskets_basket_complements)
          .group("baskets_basket_complements.basket_complement_id")
          .sum("baskets_basket_complements.quantity")
      @total_shop_complement_counts =
        @shop_orders
          .joins(items: :product_variant)
          .where.not(shop_product_variants: { basket_complement_id: nil })
          .group("shop_product_variants.basket_complement_id")
          .sum("shop_order_items.quantity")
    end

    def cached_basket_sum(depot_id, basket_size_id)
      @basket_sums_by_depot_and_size[[ depot_id, basket_size_id ]] || 0
    end

    def content_basket_sum(depot_id, basket_size_id)
      @content_basket_sums_by_depot_and_size[[ depot_id, basket_size_id ]] || 0
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

    def preload_home_delivery_addresses
      member_ids = (
        @baskets.filled.joins(:membership).pluck("memberships.member_id") +
        @shop_orders.pluck(:member_id)
      ).uniq
      @home_delivery_addresses_by_member_id =
        HomeDeliveryAddress.by_member_id_for(delivery, member_ids)
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
          .joins(items: :product_variant)
          .pluck(shop_product_variants: :basket_complement_id)
      @all_basket_complements = BasketComplement.where(id: complement_ids.uniq).ordered.to_a

      @all_shop_products = @shop_orders.products_displayed_in_delivery_sheets.to_a
    end

    def preload_basket_contents
      @basket_contents =
        if Current.org.feature?(:basket_content) && Current.org.basket_content_delivery_pdf_visible?
          delivery.basket_contents.includes(:product, :depots).to_a
        else
          []
        end
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
        .joins(items: :product_variant)
        .pluck(shop_product_variants: :basket_complement_id)
      complement_ids = complement_ids.uniq
      @all_basket_complements.select { |bc| complement_ids.include?(bc.id) }
    end

    def shop_products_for(shop_orders)
      product_ids = shop_orders.joins(:items).pluck(:product_id).uniq
      @all_shop_products.select { |p| product_ids.include?(p.id) }
    end

    def summary_density_tier
      case @depots.size
      when 0..30 then :normal
      when 31..37 then :medium
      else :compact
      end
    end

    def summary_tier_row_height(tier)
      case tier
      when :normal then 18
      when :medium then 16
      else 12
      end
    end

    def build_summary_pages
      summary_table = build_summary_table
      basket_content_table = build_summary_basket_content_table
      note = delivery.note? ? delivery.note.truncate(300) : nil

      return [ SummaryPage.new(summary_table: summary_table, basket_content_table: nil, delivery_note: note) ] unless basket_content_table

      summary_used = estimate_summary_table_height(summary_table)
      available_space = PAGE_HEIGHT - 182.0 - summary_used - 100
      rows_needed = 3 + @depots.size
      if rows_needed * 18 > available_space
        [
          SummaryPage.new(summary_table: summary_table, basket_content_table: nil, delivery_note: nil),
          SummaryPage.new(summary_table: nil, basket_content_table: basket_content_table, delivery_note: note)
        ]
      else
        [
          SummaryPage.new(
            summary_table: summary_table,
            basket_content_table: basket_content_table,
            delivery_note: note
          )
        ]
      end
    end

    def estimate_summary_table_height(summary_table)
      row_h = summary_tier_row_height(summary_table.tier)
      main_h = 22 + summary_table.main_section.rows.size * row_h
      extra_h = summary_table.extra_sections.sum { |sec| (row_h + 4) + sec.rows.size * row_h }
      main_h + extra_h
    end

    def build_summary_table
      basket_sizes = BasketSize.for(@baskets)
      basket_complements = BasketComplement.for(@baskets, @shop_orders)
      shop_products = @shop_orders.products_displayed_in_delivery_sheets

      bs_size = basket_sizes.size + 1
      bc_size = basket_complements.size
      sp_size = (@shop_orders.any? ? 1 : 0) + shop_products.size
      number_columns = bs_size + bc_size + sp_size

      _page_border, width, number_width, depot_name_width, _extra_width =
        fitted_table_geometry(number_columns)

      rotated_headers = build_summary_rotated_headers(
        basket_sizes: basket_sizes,
        basket_complements: basket_complements,
        shop_products: shop_products,
        depot_name_width: depot_name_width,
        number_width: number_width)

      columns = [
        Column.new(width: depot_name_width, align: :right, shaded: false, total: false, bold: false)
      ]
      number_columns.times do |i|
        col_idx = i + 1
        columns << Column.new(
          width: number_width,
          align: :center,
          shaded: col_idx.odd? && col_idx != bs_size,
          total: col_idx == bs_size,
          bold: col_idx == bs_size
        )
      end

      header_values = build_summary_totals_values(basket_sizes, basket_complements, shop_products)

      depot_rows = @depots.map do |depot|
        build_summary_baskets_values(
          depot,
          basket_sizes: basket_sizes,
          basket_complements: basket_complements,
          shop_products: shop_products)
      end
      extra_sections = @delivery.basket_summary_sections(depots: @depots).map do |section|
        rows = section.rows.map do |row|
          build_summary_baskets_values(
            row.depot_ids,
            title: row.title,
            basket_sizes: basket_sizes,
            basket_complements: basket_complements,
            shop_products: shop_products)
        end
        SummarySection.new(rows: rows, has_bottom_rule: rows.size.odd?)
      end

      main_has_bottom_rule = extra_sections.any? || depot_rows.size.odd?

      SummaryTable.new(
        width: width,
        depot_name_width: depot_name_width,
        tier: summary_density_tier,
        has_right_rule: columns.size.odd?,
        rotated_headers: rotated_headers,
        columns: columns,
        header_values: header_values,
        main_section: SummarySection.new(rows: depot_rows, has_bottom_rule: main_has_bottom_rule),
        extra_sections: extra_sections
      )
    end

    def build_summary_rotated_headers(basket_sizes:, basket_complements:, shop_products:, depot_name_width:, number_width:)
      offset_x = 8
      bs_total_label =
        if Current.org.delivery_basket_count_scope == :all
          Current.org.delivery_total_label
        else
          I18n.t("delivery.basket_sizes_total")
        end

      items = []
      basket_sizes.each { |bs| items << [ bs.public_name, 8, 150 ] }
      items << [ bs_total_label, 9, 150 ]
      basket_complements.each { |bc| items << [ bc.public_name, 8, 150 ] }
      items << [ I18n.t("shop.title_orders", count: 1), 8, 100 ] if @shop_orders.any?
      shop_products.each { |product| items << [ product.delivery_sheet_name, 8, 100 ] }

      items.each_with_index.map do |(label, size, width), i|
        RotatedHeader.new(
          label: label,
          left: depot_name_width + i * number_width + offset_x,
          width: width,
          color: i.even? ? "#666666" : "#000000",
          font_size: size
        )
      end
    end

    def build_summary_totals_values(basket_sizes, basket_complements, shop_products)
      values = [ Depot.model_name.human ]
      basket_sizes.each { |bs| values << (@basket_sums_by_size[bs.id] || 0).to_s }
      values << @total_basket_sum.to_s
      basket_complements.each { |c| values << shop_quantity(cached_total_complement_count(c.id)) }
      values << @shop_orders.count.to_s if @shop_orders.any?
      shop_products.each { |p| values << shop_quantity(@shop_orders.quantity_for(p)) }
      values
    end

    def build_summary_baskets_values(depot, title: nil, basket_sizes:, basket_complements:, shop_products:)
      depot_ids = summary_depot_ids(depot)
      shop_orders = @shop_orders.where(depot_id: depot_ids)

      values = [ title || depot.name ]
      basket_sizes.each do |bs|
        values << display_quantity(depot_ids.sum { |depot_id| cached_basket_sum(depot_id, bs.id) })
      end
      values << display_quantity(depot_ids.sum { |depot_id| cached_depot_basket_sum(depot_id) })
      basket_complements.each do |c|
        values << display_quantity(depot_ids.sum { |depot_id| cached_complement_count(depot_id, c.id) })
      end
      values << display_quantity(shop_orders.count) if @shop_orders.any?
      shop_products.each do |p|
        values << display_quantity(shop_orders.quantity_for(p))
      end
      values
    end

    def summary_depot_ids(depot)
      return depot.ids if depot.respond_to?(:ids)

      Array(depot).map { |value| value.is_a?(Depot) ? value.id : value }
    end

    def fitted_table_geometry(number_columns, extra_width: 0, preferred_page_border: 65, min_name_width: 80, preferred_number_width: 25)
      min_page_border = 20
      number_width = preferred_number_width
      page_border = preferred_page_border
      width = PAGE_WIDTH - 2 * page_border

      if min_name_width + extra_width + number_columns * number_width > width
        page_border = [ page_border, min_page_border ].min
        width = PAGE_WIDTH - 2 * page_border
      end

      leftover = width - min_name_width
      if leftover < extra_width + number_columns * number_width
        if leftover > extra_width && number_columns.positive?
          number_width = (leftover - extra_width).to_f / number_columns
        elsif leftover.positive? && number_columns.positive?
          extra_width = leftover * 0.3
          number_width = (leftover - extra_width).to_f / number_columns
        end
      end

      [ page_border, width, number_width, width - extra_width - number_columns * number_width, extra_width ]
    end

    def build_changes_groups
      changes = ::Delivery::Changes.new(delivery)
      return [] unless changes.any?

      changes.entries_by_depot.map do |depot_name, entries|
        ChangesGroup.new(
          depot_name: depot_name.to_s.upcase,
          entries: entries.map do |entry|
            ChangesEntry.new(
              member_name: entry.member.name,
              dimmed: entry.ended? || entry.absent?,
              changes: entry.changes
            )
          end
        )
      end
    end

    def build_depot_pages
      ordered_baskets = @baskets.joins(:member).merge(Member.order_by_name)
      depots = Array(@target_depot || @depots)

      depots.flat_map { |depot| build_pages_for_depot(depot, ordered_baskets) }
    end

    def build_pages_for_depot(depot, ordered_baskets)
      baskets = ordered_baskets.where(depot: depot)
      shop_orders = @shop_orders.where(depot: depot)
      basket_sizes = basket_sizes_for(baskets)
      member_ids = (baskets.filled.pluck(:member_id) + shop_orders.pluck(:member_id)).uniq
      members_per_page = members_per_page_for(depot)
      members = depot.sort_delivery_sheet_members(Member.where(id: member_ids), baskets)
      slices = members.each_slice(members_per_page).to_a
      return [] if slices.empty?

      preloaded_baskets = baskets.includes(:membership, :baskets_basket_complements).to_a
      preloaded_shop_orders = shop_orders.includes(items: [ :product, { product_variant: :basket_complement } ]).to_a
      basket_complements = basket_complements_for(baskets, shop_orders)
      shop_products = shop_products_for(shop_orders)
      announcement = announcement_for(depot)&.text
      basket_content_table = build_depot_basket_content_table(depot, basket_sizes)

      raw_pages = []
      slices.each_with_index do |slice, slice_idx|
        sheet_table = build_depot_sheet_table(
          depot: depot,
          members: slice,
          baskets: preloaded_baskets,
          basket_sizes: basket_sizes,
          basket_complements: basket_complements,
          shop_orders: shop_orders,
          preloaded_shop_orders: preloaded_shop_orders,
          shop_products: shop_products)

        if basket_content_table && slice_idx == slices.size - 1
          if depot_basket_content_overflows?(depot, slice.size, basket_content_table.rows.size)
            raw_pages << [ sheet_table, nil ]
            raw_pages << [ nil, basket_content_table ]
          else
            raw_pages << [ sheet_table, basket_content_table ]
          end
        else
          raw_pages << [ sheet_table, nil ]
        end
      end

      total_pages = raw_pages.size
      raw_pages.each_with_index.map do |(sheet_table, bc_table), idx|
        DepotPage.new(
          depot_name: depot.public_name,
          announcement: announcement,
          page: idx + 1,
          total_pages: total_pages,
          sheet_table: sheet_table,
          basket_content_table: bc_table
        )
      end
    end

    def members_per_page_for(depot)
      if Current.org.delivery_pdf_member_info == "phones" || depot.delivery_sheets_mode == "home_delivery"
        16
      elsif Current.org.delivery_pdf_member_info == "food_note"
        19
      else
        22
      end
    end

    def depot_basket_content_overflows?(depot, member_count, product_count)
      row_h =
        if Current.org.delivery_pdf_member_info == "phones" || depot.delivery_sheets_mode == "home_delivery"
          36
        elsif Current.org.delivery_pdf_member_info == "food_note"
          30
        else
          26
        end
      cursor = PAGE_HEIGHT - 210.36 - 28 - member_count * row_h
      available_space = cursor - 100
      80 + product_count * 20 > available_space
    end

    def build_depot_sheet_table(depot:, members:, baskets:, basket_sizes:, basket_complements:, shop_orders:, preloaded_shop_orders:, shop_products:)
      home_delivery = depot.delivery_sheets_mode == "home_delivery"
      bs_size = basket_sizes.size
      bc_size = basket_complements.size
      has_shop_orders = shop_orders.any?
      sp_size = (has_shop_orders ? 1 : 0) + shop_products.size
      number_columns = bs_size + bc_size + sp_size

      _page_border, width, number_width, member_name_width, extra_width =
        fitted_table_geometry(
          number_columns,
          extra_width: 110,
          preferred_page_border: 20)
      address_width = home_delivery ? (member_name_width / 2.0) : 0
      name_col_width = member_name_width - address_width

      rotated_headers = build_depot_rotated_headers(
        basket_sizes: basket_sizes,
        basket_complements: basket_complements,
        has_shop_orders: has_shop_orders,
        shop_products: shop_products,
        offset_base: member_name_width,
        number_width: number_width)

      colors_offset = home_delivery ? 1 : 0
      column_count = (home_delivery ? 2 : 1) + number_columns + 1
      show_last_col_left_border = (column_count % 2) == colors_offset

      column_widths = [ name_col_width ]
      column_widths << address_width if home_delivery
      number_columns.times { column_widths << number_width }
      column_widths << extra_width

      header_cells = build_depot_header_cells(
        depot: depot,
        home_delivery: home_delivery,
        basket_sizes: basket_sizes,
        basket_complements: basket_complements,
        shop_orders: shop_orders,
        has_shop_orders: has_shop_orders,
        shop_products: shop_products,
        show_last_col_left_border: show_last_col_left_border)

      rows = members.map do |member|
        basket = baskets.find { |b| b.membership.member_id == member.id }
        shop_order = preloaded_shop_orders.find { |so| so.member_id == member.id }
        absent = basket&.absent? == true
        overlay = absent ? nil : @home_delivery_addresses_by_member_id[member.id]

        name_text = home_delivery ? member.name : Current.org.format_member_name_for_pdf(member.name)
        info_text = member_info_text(member)

        address_lines =
          if home_delivery
            if overlay
              overlay.sheet_address.to_s.split("\n")
            else
              [ member.street, "#{member.zip} #{member.city}" ]
            end
          end

        counters = build_depot_member_counters(
          basket: basket,
          shop_order: shop_order,
          absent: absent,
          basket_sizes: basket_sizes,
          basket_complements: basket_complements,
          has_shop_orders: has_shop_orders,
          shop_products: shop_products)

        extra_text =
          if absent
            Basket.human_attribute_name(:absent).upcase
          elsif home_delivery
            overlay ? overlay.sheet_note : member.delivery_note
          else
            ""
          end

        DepotMemberRow.new(
          name: name_text,
          info: info_text,
          absent: absent,
          address_lines: address_lines,
          address_overlay: home_delivery && overlay.present?,
          counters: counters,
          extra_text: extra_text.to_s,
          extra_overlay: home_delivery && !absent && overlay&.note.present?
        )
      end

      DepotSheetTable.new(
        width: width,
        name_col_width: name_col_width,
        address_col_width: address_width,
        home_delivery: home_delivery,
        show_last_col_left_border: show_last_col_left_border,
        has_bottom_rule: rows.size.odd?,
        rotated_headers: rotated_headers,
        column_widths: column_widths,
        header_cells: header_cells,
        rows: rows
      )
    end

    def build_depot_rotated_headers(basket_sizes:, basket_complements:, has_shop_orders:, shop_products:, offset_base:, number_width:)
      offset_x = 6
      labels = []
      basket_sizes.each { |bs| labels << bs.public_name }
      basket_complements.each { |bc| labels << bc.public_name }
      labels << I18n.t("shop.title_orders", count: 1) if has_shop_orders
      shop_products.each { |product| labels << product.delivery_sheet_name }

      labels.each_with_index.map do |label, i|
        RotatedHeader.new(
          label: label,
          left: offset_base + i * number_width + offset_x,
          width: 150,
          color: i.even? ? "#666666" : "#000000",
          font_size: 10
        )
      end
    end

    def build_depot_header_cells(depot:, home_delivery:, basket_sizes:, basket_complements:, shop_orders:, has_shop_orders:, shop_products:, show_last_col_left_border:)
      cells = [
        DepotHeaderCell.new(
          text: Member.model_name.human,
          align: home_delivery ? :left : :right,
          shaded: false,
          left_border: false
        )
      ]
      if home_delivery
        cells << DepotHeaderCell.new(
          text: ::Delivery.human_attribute_name(:address),
          align: :left,
          shaded: false,
          left_border: false
        )
      end

      counter_idx = 0
      append_counter = ->(text) {
        cells << DepotHeaderCell.new(
          text: text,
          align: :center,
          shaded: counter_idx.even?,
          left_border: false
        )
        counter_idx += 1
      }

      basket_sizes.each { |bs| append_counter.call(cached_basket_sum(depot.id, bs.id).to_s) }
      basket_complements.each { |c| append_counter.call(shop_quantity(cached_complement_count(depot.id, c.id))) }
      append_counter.call(shop_orders.count.to_s) if has_shop_orders
      shop_products.each { |p| append_counter.call(shop_quantity(shop_orders.quantity_for(p))) }

      extra_label =
        case depot.delivery_sheets_mode
        when "signature" then ::Delivery.human_attribute_name(:signature)
        when "home_delivery" then ::Member.human_attribute_name(:note)
        end
      cells << DepotHeaderCell.new(
        text: extra_label.to_s,
        align: :right,
        shaded: false,
        left_border: show_last_col_left_border
      )
      cells
    end

    def build_depot_member_counters(basket:, shop_order:, absent:, basket_sizes:, basket_complements:, has_shop_orders:, shop_products:)
      values = []
      basket_sizes.each do |bs|
        values << ((basket && basket.basket_size_id == bs.id) ? display_quantity(basket.quantity) : "")
      end
      basket_complements.each do |c|
        quantity = basket&.baskets_basket_complements&.find { |bbc| bbc.basket_complement_id == c.id }&.quantity || 0
        if shop_order
          quantity += shop_order.items
            .select { |item| item.product_variant.basket_complement_id == c.id }
            .sum(&:quantity)
        end
        values << display_quantity(quantity)
      end
      if has_shop_orders
        values << (absent ? "–" : (shop_order ? "X" : ""))
      end
      shop_products.each do |p|
        values << if absent
          "–"
        elsif shop_order
          shop_order_item = shop_order.items.find { |i| i.product_id == p.id }
          display_quantity(shop_order_item&.quantity || 0)
        else
          ""
        end
      end

      values.each_with_index.map do |text, i|
        DepotCounterCell.new(
          text: text,
          shaded: i.even?,
          absent: absent
        )
      end
    end

    def member_info_text(member)
      case Current.org.delivery_pdf_member_info
      when "phones"
        phones = member.phones_array
        phones.map { |p| display_phone(p) }.join(", ") if phones.any?
      when "food_note"
        member.food_note.truncate(90) if member.food_note?
      end
    end

    def build_summary_basket_content_table
      return if @basket_contents.empty?

      products = @basket_contents.sort_by { |bc| bc.product.name }
      page_border, width, number_width, depot_name_width, _extra =
        fitted_table_geometry(
          products.size,
          preferred_page_border: 40,
          min_name_width: 80,
          preferred_number_width: 40)

      offset_x = [ (number_width * 0.375).round(1), 15 ].min
      rotated_headers = products.each_with_index.map do |bc, i|
        RotatedHeader.new(
          label: bc.product.name,
          left: depot_name_width + i * number_width + offset_x,
          width: 150,
          color: i.even? ? "#666666" : "#000000",
          font_size: 8
        )
      end

      columns = [
        Column.new(width: depot_name_width, align: :right, shaded: false, total: false, bold: false)
      ]
      products.size.times do |i|
        col_idx = i + 1
        columns << Column.new(width: number_width, align: :right, shaded: col_idx.odd?, total: false, bold: false)
      end

      header_cells = [ BasketContentCell.new(text: Depot.model_name.human, align: :right) ]
      products.each do |bc|
        total_qty = @depots.sum { |depot| basket_content_depot_total(bc, [ depot.id ]) }
        header_cells << BasketContentCell.new(text: format_basket_content_quantity(total_qty, bc.unit), align: :right)
      end

      rows = @depots.map do |depot|
        cells = [ BasketContentCell.new(text: depot.name, align: :right) ]
        products.each do |bc|
          qty = basket_content_depot_total(bc, [ depot.id ])
          cells << BasketContentCell.new(
            text: format_basket_content_quantity(qty, bc.unit),
            align: qty.positive? ? :right : :center
          )
        end
        cells
      end

      BasketContentTable.new(
        page_border: page_border,
        width: width,
        tier: summary_density_tier,
        variant: :summary,
        has_right_rule: columns.size.odd?,
        has_bottom_rule: rows.size.odd?,
        rotated_headers: rotated_headers,
        columns: columns,
        header_cells: header_cells,
        rows: rows
      )
    end

    def build_depot_basket_content_table(depot, basket_sizes)
      return if @basket_contents.empty?

      depot_contents = basket_content_for_depot(depot)
      return if depot_contents.empty?

      products = depot_contents.sort_by { |bc| bc.product.name }
      total_columns = basket_sizes.size + 1
      page_border, width, number_width, product_name_width, _extra =
        fitted_table_geometry(
          total_columns,
          preferred_page_border: 40,
          min_name_width: 80,
          preferred_number_width: 50)

      offset_x = number_width / 2.0 - 3
      rotated_headers = basket_sizes.each_with_index.map do |bs, i|
        RotatedHeader.new(
          label: bs.public_name,
          left: product_name_width + i * number_width + offset_x,
          width: 150,
          color: i.even? ? "#666666" : "#000000",
          font_size: 10
        )
      end
      rotated_headers << RotatedHeader.new(
        label: I18n.t("delivery.total"),
        left: product_name_width + basket_sizes.size * number_width + offset_x,
        width: 150,
        color: "#000000",
        font_size: 12
      )

      columns = [
        Column.new(width: product_name_width, align: :right, shaded: false, total: false, bold: false)
      ]
      total_columns.times do |i|
        col_idx = i + 1
        columns << Column.new(
          width: number_width,
          align: :right,
          shaded: col_idx.odd?,
          total: false,
          bold: col_idx == total_columns
        )
      end

      rows = products.map do |bc|
        cells = [ BasketContentCell.new(text: bc.product.name, align: :right) ]
        basket_sizes.each do |bs|
          qty = bc.basket_quantity(bs)
          cells << BasketContentCell.new(
            text: format_basket_content_quantity(qty, bc.unit),
            align: qty.positive? ? :right : :center
          )
        end
        total_qty = basket_content_depot_total(bc, [ depot.id ])
        cells << BasketContentCell.new(
          text: format_basket_content_quantity(total_qty, bc.unit),
          align: total_qty.positive? ? :right : :center
        )
        cells
      end

      BasketContentTable.new(
        page_border: page_border,
        width: width,
        tier: :normal,
        variant: :depot,
        has_right_rule: columns.size.odd?,
        has_bottom_rule: rows.size.even?,
        rotated_headers: rotated_headers,
        columns: columns,
        header_cells: nil,
        rows: rows
      )
    end

    def display_quantity(quantity)
      quantity.to_d.zero? ? "" : shop_quantity(quantity)
    end

    def basket_content_for_depot(depot)
      depot_id = depot.is_a?(Depot) ? depot.id : depot
      @basket_contents.select { |bc| bc.depot_ids.include?(depot_id) }
    end

    def basket_content_depot_total(basket_content, depot_ids)
      return 0 if (basket_content.depot_ids & depot_ids).empty?

      basket_content.basket_sizes.sum do |bs|
        quantity_per_basket = basket_content.basket_quantity(bs)
        baskets_count = depot_ids.sum { |did| content_basket_sum(did, bs.id) }
        quantity_per_basket * baskets_count
      end
    end

    def format_basket_content_quantity(quantity, unit)
      return "\u2013" if quantity.zero?

      sep = "\u202F"
      case unit
      when "kg"
        if quantity < 1
          grams = (quantity * 1000).to_i
          "#{grams}#{sep}g\u00A0\u00A0"
        elsif quantity < 10
          "#{number_with_precision(quantity, precision: 2)}#{sep}kg"
        elsif quantity < 100
          "#{number_with_precision(quantity, precision: 1)}#{sep}kg"
        else
          "#{quantity.to_i}#{sep}kg"
        end
      when "pc"
        "#{quantity.to_i}#{sep}pc"
      end
    end
  end
end
