module XLSX
  class Delivery < Base
    def initialize(delivery, depot = nil)
      @delivery = delivery
      @depot = depot
      @baskets = @delivery.baskets.not_absent.includes(:member)
      @shop_orders =
        @delivery
          .shop_orders
          .all_without_cart
          .includes(:member, items: { product: :basket_complement })
      @depots = Depot.where(id: (@baskets.pluck(:depot_id) + @shop_orders.pluck(:depot_id)).uniq)
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
      if @shop_orders.any?
        cols << ''
        cols << I18n.t('shop.title_orders', count: 2)
      end
      add_headers(*cols)

      @depots.each do |depot|
        add_baskets_line(depot)
      end
      add_empty_line

      if @depots.any?(&:free?) && @depots.any?(&:paid?)
        add_baskets_line(@depots.free, title: t('free_depots'))
        add_baskets_line(@depots.paid, title: t('paid_depots'))
        add_empty_line
      end

      add_baskets_line(nil, bold: true, title: t('total'))

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

    def add_baskets_line(depot, bold: false, title: nil)
      baskets = depot ? @baskets.where(depot: depot) : @baskets
      @worksheet.add_cell(@line, 0, title || depot.name)
      @worksheet.add_cell(@line, 1, baskets.sum(:quantity)).set_number_format('0')
      @basket_sizes.each_with_index do |basket_size, i|
        amount = baskets.where(basket_size_id: basket_size.id).sum(:quantity)
        @worksheet.add_cell(@line, 2 + i, amount).set_number_format('0')
      end

      shop_orders = depot ? @shop_orders.where(depot: depot) : @shop_orders
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
              shop_orders
                .joins(:products)
                .where(shop_products: { basket_complement_id: complement.id })
                .sum('shop_order_items.quantity')
          end
          @worksheet.add_cell(@line, cols_count + i, amount).set_number_format('0')
        end
      end

      if shop_orders.any?
        cols_count = 4 + @basket_sizes.count + @basket_complements.count
        @worksheet.add_cell(@line, cols_count, shop_orders.count).set_number_format('0')
      end

      @worksheet.change_row_bold(@line, bold)

      @line += 1
    end

    def build_depot_worksheet(depot)
      baskets = @baskets.where(depot: depot).includes(:membership, :basket_size, :complements, baskets_basket_complements: :basket_complement)
      shop_orders = @shop_orders.where(depot: depot)
      member_ids = (baskets.pluck(:member_id) + shop_orders.pluck(:member_id)).uniq
      members = Member.where(id: member_ids).order(:name)
      members.each do |member|
        member.basket = baskets.find { |b| b.membership.member_id == member.id }
        member.shop_order = shop_orders.find { |so| so.member_id == member.id }
      end
      basket_counts = @basket_sizes.map { |bs| baskets.where(basket_size: bs).sum(:quantity) }

      add_members_worksheet(depot.name, members, style: depot.xlsx_worksheet_style)
    end

    def build_absences_worksheet
      baskets = @delivery.baskets.absent.includes(:membership, :member, :basket_size, :complements, baskets_basket_complements: :basket_complement)

      members = baskets.map(&:member).sort_by(&:name)
      members.each do |member|
        member.basket = baskets.find { |b| b.membership.member_id == member.id }
      end

      add_members_worksheet(Absence.model_name.human(count: 2), members)
    end

    def add_members_worksheet(name, members, style: 'default')
      if style == 'bike_delivery'
        members = members.sort_by { |m|
          [m.final_delivery_zip, m.final_delivery_city, m.final_delivery_address]
        }
      end
      border = style == 'bike_delivery' ? 'thin' : 'none'

      name = worksheet_name(name, members.size)
      add_worksheet(name)

      add_column(
        Member.human_attribute_name(:name),
        members.map { |m| m.name },
        border: border)
      add_column(
        Member.human_attribute_name(:phones),
        members.map { |m| m.phones_array.map { |p| display_phone(p) }.join(', ') },
        border: border)
      unless style == 'bike_delivery'
        add_column(
          Member.human_attribute_name(:emails),
          members.map { |m| m.emails_array.join(', ') },
          border: border)
      end
      add_column(
        Member.human_attribute_name(:address),
        members.map { |m| m.final_delivery_address },
        border: border)
      unless style == 'bike_delivery'
        add_column(
          Member.human_attribute_name(:zip),
          members.map { |m| m.final_delivery_zip },
          border: border)
      end
      add_column(
        Member.human_attribute_name(:city),
        members.map { |m| m.final_delivery_city },
        border: border)
      add_column(
        Basket.model_name.human(count: 1),
        members.map { |m| m.basket&.basket_description || '-' },
        border: border)
      if @basket_complements.any?
        add_column(
          Basket.human_attribute_name(:complement_ids),
          members.map { |m| m.basket&.complements_description },
          border: border)
        if Current.acp.feature?('shop')
          add_column(
            "#{Basket.human_attribute_name(:complement_ids)} (#{::Shop::Order.model_name.human(count: 1)})",
            members.map { |m| m.shop_order&.complements_description },
            border: border)
          add_column(
            I18n.t('shop.title_orders', count: 2),
            members.map { |m| m.shop_order ? 'X' : '' },
            border: border)
        end
      end
      unless style == 'bike_delivery'
        add_column(
          Member.human_attribute_name(:note),
          members.map { |m| truncate(m.note, length: 160) },
          border: border)
        add_column(
          Member.human_attribute_name(:food_note),
          members.map { |m| truncate(m.food_note, length: 80) },
          border: border)
      end
      if style == 'bike_delivery'
        add_column(t('delivered_by'), members.map { |m| ' ' * 25 }, border: border)
      end
    end

    def t(key, *args)
      I18n.t("delivery.#{key}", *args)
    end

    def worksheet_name(name, extra = '')
      extra = " – #{extra}"
      extra_length = extra ? " – #{extra}".length : 0
      name.truncate(31 - extra_length) + extra
    end
  end
end
