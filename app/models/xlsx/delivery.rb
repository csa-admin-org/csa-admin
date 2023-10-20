module XLSX
  class Delivery < Base
    def initialize(delivery, depot = nil)
      @delivery = delivery
      @baskets = @delivery.baskets.not_absent
      @shop_orders = @delivery.shop_orders.all_without_cart
      @shop_products = @shop_orders.products_displayed_in_delivery_sheets
      @depots = Depot.where(id: (@baskets.pluck(:depot_id) + @shop_orders.pluck(:depot_id)).uniq)
      @basket_complements = BasketComplement.for(@baskets, @shop_orders)
      @basket_sizes = BasketSize.for(@baskets)

      build_summary_worksheet unless depot

      @baskets = @baskets.includes(:member).order('members.name')

      Array(depot || @depots).each do |d|
        build_depot_worksheet(d)
      end

      if Current.acp.feature?('absence')
        build_absences_worksheet if !depot && @delivery.baskets.absent.any?
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

    def build_summary_worksheet
      add_worksheet(t('summary'))

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
      if @shop_products.any?
        cols << ''
        cols += @shop_products.map(&:name_with_single_variant)
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
          amount = baskets.complement_count(complement)
          if Current.acp.feature?('shop')
            amount += shop_orders.complement_count(complement)
          end
          @worksheet.add_cell(@line, cols_count + i, amount).set_number_format('0')
        end
      end

      if shop_orders.any?
        cols_count = 4 + @basket_sizes.count + @basket_complements.count
        @worksheet.add_cell(@line, cols_count, shop_orders.count).set_number_format('0')
      end

      if @shop_products.any?
        cols_count += 2
        @shop_products.each_with_index do |product, i|
          amount = shop_orders.quantity_for(product)
          @worksheet.add_cell(@line, cols_count + i, amount).set_number_format('0')
        end
      end

      @worksheet.change_row_bold(@line, bold)

      @line += 1
    end

    def build_depot_worksheet(depot)
      baskets = @baskets.where(depot: depot).includes(:membership, :basket_size, :complements, baskets_basket_complements: :basket_complement)
      shop_orders = @shop_orders.where(depot: depot).includes(:member, items: { product: :basket_complement })
      member_ids = (baskets.not_empty.pluck(:member_id) + shop_orders.pluck(:member_id)).uniq
      members = Member.where(id: member_ids).sort_by { |m| depot.member_sorting(m) }
      members.each do |member|
        member.basket = baskets.find { |b| b.membership.member_id == member.id }
        member.shop_order = shop_orders.find { |so| so.member_id == member.id }
      end
      basket_counts = @basket_sizes.map { |bs| baskets.where(basket_size: bs).sum(:quantity) }

      add_members_worksheet(depot.name, members, mode: depot.delivery_sheets_mode)
    end

    def build_absences_worksheet
      baskets = @delivery.baskets.absent.includes(:membership, :member, :basket_size, :complements, baskets_basket_complements: :basket_complement)

      members = baskets.map(&:member).sort_by(&:name)
      members.each do |member|
        member.basket = baskets.find { |b| b.membership.member_id == member.id }
      end

      add_members_worksheet(Absence.model_name.human(count: 2), members)
    end

    def add_members_worksheet(name, members, mode: 'signature')
      border = mode == 'home_delivery' ? 'thin' : 'none'

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
      unless mode == 'home_delivery'
        add_column(
          Member.human_attribute_name(:emails),
          members.map { |m| m.emails_array.join(', ') },
          border: border)
      end
      add_column(
        Member.human_attribute_name(:address),
        members.map { |m| m.final_delivery_address },
        border: border)
      unless mode == 'home_delivery'
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
      end
      if Current.acp.feature?('shop')
        add_column(
          I18n.t('shop.title_orders', count: 2),
          members.map { |m| m.shop_order ? 'X' : '' },
          border: border)
        if @basket_complements.any?
          add_column(
            "#{Basket.human_attribute_name(:complement_ids)} (#{::Shop::Order.model_name.human(count: 1)})",
            members.map { |m| m.shop_order&.complements_description },
            border: border)
        end
        if @shop_products.any?
          add_column(
            "#{::Shop::Product.model_name.human(count: 2)} (#{I18n.t('shop.title')})",
            members.map { |m|
              @shop_products.map { |p|
                quantity = m.shop_order&.items&.find { |i| i.product_id == p.id }&.quantity
                quantity ? "#{quantity}x #{p.name_with_single_variant}" : nil
              }.compact.join(', ')
            },
            border: border)
        end
      end
      unless mode == 'home_delivery'
        add_column(
          Member.human_attribute_name(:food_note),
          members.map { |m| truncate(m.food_note, length: 80) },
          border: border)
      end
      if mode == 'home_delivery'
        add_column(
          Member.human_attribute_name(:note),
          members.map { |m| truncate(m.delivery_note, length: 160) },
          border: border)
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
