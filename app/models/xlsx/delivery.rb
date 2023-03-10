module XLSX
  class Delivery < Base
    def initialize(delivery, depot = nil)
      @delivery = delivery
      @depot = depot
      @baskets = @delivery.baskets.not_absent.includes(:member)
      @depots = Depot.where(id: @baskets.pluck(:depot_id).uniq)
      basket_complement_ids =
        @baskets
          .joins(:baskets_basket_complements)
          .pluck('baskets_basket_complements.basket_complement_id')
          .uniq
      @basket_complements = BasketComplement.find(basket_complement_ids)
      basket_size_ids = @baskets.pluck(:basket_size_id).uniq
      @basket_sizes = BasketSize.find(basket_size_ids)

      build_recap_worksheet unless @depot

      Array(@depot || @depots).each do |d|
        build_depot_worksheet(d)
      end

      if Current.acp.feature?('absence')
        build_absences_worksheet if !@depot && @delivery.baskets.absent.any?
      end
    end

    def filename
      [
        t('delivery'),
        @delivery.display_number,
        @delivery.date.strftime('%Y%m%d')
      ].join('-') + '.xlsx'
    end

    private

    def build_recap_worksheet
      add_worksheet(t('recap'))

      cols = ['', t('total')]
      cols += @basket_sizes.map(&:name)
      if @basket_complements.any?
        cols << ''
        cols += @basket_complements.map(&:name)
      end
      add_headers(*cols)

      @depots.each do |depot|
        add_baskets_line(depot.name, @baskets.where(depot_id: depot.id))
      end
      add_empty_line

      if Depot.paid.any? && free_depots = @depots.free
        free_name = free_depots.pluck(:name).to_sentence
        free_ids = free_depots.pluck(:id)
        add_baskets_line("#{Basket.model_name.human(count: 2)}: #{free_name}", @baskets.where(depot_id: free_ids))
        paid_ids = @depots.paid.pluck(:id)
        add_baskets_line(t('baskets_to_prepare'), @baskets.where(depot_id: paid_ids))
        add_empty_line
      end

      add_baskets_line(t('total'), @baskets, bold: true)

      if Current.acp.feature?('absence')
        add_empty_line
        add_empty_line

        @worksheet.add_cell(@line, 0, Absence.model_name.human(count: 2))
        @worksheet.add_cell(@line, 1, @delivery.baskets.absent.sum(:quantity)).set_number_format('0')
      end

      @worksheet.change_column_width(0, 35)
      (1..(2 + @basket_sizes.count + @basket_complements.count)).each do |i|
        @worksheet.change_column_width(i, 15)
        @worksheet.change_column_horizontal_alignment(i, 'right')
      end
    end

    def add_baskets_line(description, baskets, bold: false)
      @worksheet.add_cell(@line, 0, description)
      @worksheet.add_cell(@line, 1, baskets.sum(:quantity)).set_number_format('0')
      @basket_sizes.each_with_index do |basket_size, i|
        amount = baskets.where(basket_size_id: basket_size.id).sum(:quantity)
        @worksheet.add_cell(@line, 2 + i, amount).set_number_format('0')
      end
      if @basket_complements.any?
        cols_count = 3 + @basket_sizes.count
        @basket_complements.each_with_index do |complement, i|
          amount =
            baskets
              .joins(:baskets_basket_complements)
              .where(baskets_basket_complements: { basket_complement_id: complement.id })
              .sum('baskets_basket_complements.quantity')
          if Current.acp.feature?('shop')
            amount +=
              @delivery
                .shop_orders
                .joins(:products)
                .where(shop_products: { basket_complement_id: complement.id })
                .where(shop_orders: { member_id: baskets.map { |b| b.member.id } })
                .sum('shop_order_items.quantity')
          end
          @worksheet.add_cell(@line, cols_count + i, amount).set_number_format('0')
        end
      end
      @worksheet.change_row_bold(@line, bold)

      @line += 1
    end

    def build_depot_worksheet(depot)
      baskets = @baskets.where(depot_id: depot.id)
      basket_counts = @basket_sizes.map { |bs| baskets.where(basket_size_id: bs.id).sum(:quantity) }
      worksheet_name = "#{depot.name} (#{basket_counts.join('+')})"

      add_baskets_worksheet(worksheet_name, baskets, style: depot.xlsx_worksheet_style)
    end

    def build_absences_worksheet
      baskets = @delivery.baskets.absent
      basket_counts = @basket_sizes.map { |bs| baskets.where(basket_size_id: bs.id).sum(:quantity) }
      worksheet_name =
        "#{Absence.model_name.human(count: basket_counts.sum)} (#{basket_counts.join('+')})"

      add_baskets_worksheet(worksheet_name, baskets)
    end

    def add_baskets_worksheet(name, baskets, style: 'default')
      baskets = baskets
        .joins(:member)
        .includes(:member, :membership, :basket_size, :complements, baskets_basket_complements: :basket_complement, membership: :member)
        .not_empty

      baskets =
        if style == 'bike_delivery'
          baskets.sort_by { |b|
            [b.member.final_delivery_zip, b.member.final_delivery_city, b.member.final_delivery_address]
          }
        else
          baskets.order('members.name')
        end

      border = style == 'bike_delivery' ? 'thin' : 'none'

      add_worksheet(name)

      add_column(
        Member.human_attribute_name(:name),
        baskets.map { |b| b.member.name },
        border: border)
      add_column(
        Member.human_attribute_name(:phones),
        baskets.map { |b| b.member.phones_array.map { |p| display_phone(p) }.join(', ') },
        border: border)
      unless style == 'bike_delivery'
        add_column(
          Member.human_attribute_name(:emails),
          baskets.map { |b| b.member.emails_array.join(', ') },
          border: border)
      end
      add_column(
        Member.human_attribute_name(:address),
        baskets.map { |b| b.member.final_delivery_address },
        border: border)
      unless style == 'bike_delivery'
        add_column(
          Member.human_attribute_name(:zip),
          baskets.map { |b| b.member.final_delivery_zip },
          border: border)
      end
      add_column(
        Member.human_attribute_name(:city),
        baskets.map { |b| b.member.final_delivery_city },
        border: border)
      add_column(
        Basket.model_name.human(count: 1),
        baskets.map { |b| b.basket_description || '-' },
        border: border)
      if @basket_complements.any?
        add_column(
          Basket.human_attribute_name(:complement_ids),
          baskets.map(&:complements_description),
          border: border)
        if Current.acp.feature?('shop')
          shop_orders =
            @delivery
              .shop_orders
              .joins(items: { product: :basket_complement })
              .includes(items: { product: :basket_complement })
          add_column(
            "#{Basket.human_attribute_name(:complement_ids)} (#{::Shop::Order.model_name.human(count: 1)})",
            baskets.map { |b|
              shop_orders.find { |o| o.member_id == b.member.id }&.complements_description
            },
            border: border)
        end
      end
      unless style == 'bike_delivery'
        add_column(
          Member.human_attribute_name(:note),
          baskets.map { |b| truncate(b.member.note, length: 160) },
          border: border)
        add_column(
          Member.human_attribute_name(:food_note),
          baskets.map { |b| truncate(b.member.food_note, length: 80) },
          border: border)
      end
      if style == 'bike_delivery'
        add_column(t('delivered_by'), baskets.map { |b| ' ' * 25 }, border: border)
      end
    end

    def t(key, *args)
      I18n.t("delivery.#{key}", *args)
    end
  end
end
