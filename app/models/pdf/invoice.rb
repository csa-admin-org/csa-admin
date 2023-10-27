module PDF
  class Invoice < Base
    include ActivitiesHelper
    include MembershipsHelper
    include NumbersHelper

    ITEMS_PER_PAGE = 40
    MAX_ITEMS_ON_LAST_PAGE = 10

    attr_reader :invoice, :entity

    def initialize(invoice)
      @invoice = invoice
      @entity = invoice.entity
      # Reload entity to be sure that the balance is up-to-date
      @missing_amount = ::Invoice.find(invoice.id).missing_amount
      super

      smart_pages(invoice.items.to_a)
    end

    private

    def smart_pages(items)
      if items.size > MAX_ITEMS_ON_LAST_PAGE
        first_items = items.first(items.size - MAX_ITEMS_ON_LAST_PAGE)
        first_total_pages = (first_items.size / ITEMS_PER_PAGE.to_f).ceil
        items_per_page = (first_items.size / (first_total_pages).to_f).ceil
        first_items.each_slice(items_per_page).with_index do |items_slice, i|
          page(items_slice, page: i + 1, total_pages: first_total_pages + 1)
        end

        total_pages = first_total_pages + 1
        last_items = items.last(MAX_ITEMS_ON_LAST_PAGE)
        page(last_items, page: total_pages, total_pages: total_pages)
      else
        page(items, page: 1, total_pages: 1)
      end
    end

    def page(items, page:, total_pages:)
      last_page = page == total_pages
      header(page: page, total_pages: total_pages)
      content(items, last_page: last_page)
      footer(last_page: last_page)
      last_page ? qr : start_new_page
    end

    def info
      super.merge(Title: "#{::Invoice.model_name.human} #{invoice.id}")
    end

    def header(page:, total_pages:)
      image acp_logo_io, at: [15, bounds.height - 20], width: 110
      bounding_box [155, bounds.height - 55], width: 200, height: 2.6.cm do
        text "#{::Invoice.model_name.human} N° #{invoice.id}", style: :bold, size: 16
        move_down 5
        text I18n.l(invoice.date)
        case invoice.entity_type
        when 'Membership'
          move_down 5
          text membership_short_period(entity), size: 10
        when 'Shop::Order'
          move_down 12
          text "#{::Shop::Order.model_name.human} N° #{entity.id}"
          move_down 5
          text "#{::Delivery.model_name.human}: #{I18n.l(entity.delivery.date)}"
        end
      end
      member_address

      if total_pages > 1
        bounding_box [bounds.width - 65, bounds.height - 30], width: 50, height: 50 do
          text "#{page} / #{total_pages}", align: :center, style: :bold, size: 16
        end
        move_down 40
      end
    end

    def member_address
      member = invoice.member
      parts = [
        member.name.truncate(70),
        member.address.truncate(70),
        "#{member.zip} #{member.city}"
      ]

      bounding_box [11.5.cm, bounds.height - 55], width: 8.cm, height: 2.5.cm do
        parts.each do |part|
          text part, valign: :top, leading: 2
          move_down 2
        end
        if invoice.acp_share_type? && invoice.member.acp_shares_info?
          move_down 6
          attr_name = Member.human_attribute_name(:acp_shares_info)
          text "#{attr_name}: #{invoice.member.acp_shares_info}", valign: :top, leading: 2, size: 10
        end
      end
    end

    def content(items, last_page:)
      font_size 10
      data = [[
        ::Invoice.human_attribute_name(:description),
        "#{::Invoice.human_attribute_name(:amount)} (#{currency_symbol})"
      ]]

      case invoice.entity_type
      when 'Membership'
        if entity.basket_sizes_price.positive?
          entity.basket_sizes.uniq.each do |basket_size|
            data << [
              membership_basket_size_description(basket_size),
              _cur(entity.basket_size_price(basket_size))
            ]
          end
        end
        if Current.acp.feature?('basket_price_extra') && !entity.baskets_price_extra.zero?
          data << [
            membership_baskets_price_extra_description,
            _cur(entity.baskets_price_extra)
          ]
        end
        unless entity.baskets_annual_price_change.zero?
          data << [
            t('baskets_annual_price_change'),
            _cur(entity.baskets_annual_price_change)
          ]
        end
        if entity.basket_complements_price.positive?
          basket_complements = (
            entity.basket_complements + entity.subscribed_basket_complements
          ).uniq
          basket_complements.each do |basket_complement|
            data << [
              membership_basket_complement_description(basket_complement),
              _cur(entity.basket_complement_total_price(basket_complement))
            ]
          end
        end
        unless entity.basket_complements_annual_price_change.zero?
          data << [
            t('basket_complements_annual_price_change'),
            _cur(entity.basket_complements_annual_price_change)
          ]
        end
        entity.depots.uniq.each do |depot|
          price = entity.depot_total_price(depot)
          if price.positive?
            data << [
              membership_depot_description(depot),
              _cur(price)
            ]
          end
        end
        unless entity.activity_participations_annual_price_change.zero?
          data << [activity_participations_annual_price_change_description, _cur(entity.activity_participations_annual_price_change)]
        end
      when 'ActivityParticipation'
        if entity
          str = t_activity('missed_activity_participation_with_date', date: I18n.l(entity.activity.date))
          if invoice.paid_missing_activity_participations > 1
            str += " (#{invoice.paid_missing_activity_participations} #{ActivityParticipation.human_attribute_name(:participants).downcase})"
          end
        elsif invoice.paid_missing_activity_participations == 1
          str = t_activity('missed_activity_participation')
        else
          str = t_activity('missed_activity_participations', count: invoice.paid_missing_activity_participations)
        end
        data << [str, _cur(invoice.amount)]
      when 'ACPShare'
        str =
          if invoice.acp_shares_number.positive?
            t('acp_shares_number', count: invoice.acp_shares_number)
          else
            t('acp_shares_number_negative', count: invoice.acp_shares_number.abs)
          end
        data << [str, _cur(invoice.amount)]
      when 'Other', 'Shop::Order', 'NewMemberFee'
        items.each do |item|
          data << [item.description, _cur(item.amount)]
        end
      end

      if last_page
        if invoice.paid_memberships_amount.to_f.positive?
          data << [
            t('paid_memberships_amount'),
            _cur(-invoice.paid_memberships_amount)
          ]
          data << [
            t('remaining_annual_memberships_amount'),
            _cur(invoice.remaining_memberships_amount)
          ]
        elsif invoice.remaining_memberships_amount?
          data << [
            t('annual_memberships_amount'),
            _cur(invoice.remaining_memberships_amount)
          ]
        end

        if invoice.memberships_amount?
          data << [
            invoice.memberships_amount_description,
            _cur_with_vat_appendice(invoice, invoice.memberships_amount)
          ]
        end

        if invoice.annual_fee?
          data << [t('annual_fee'), _cur(invoice.annual_fee)]
        end

        if invoice.amount_percentage?
          data << [t('total_before_percentage'), _cur(invoice.amount_before_percentage)]
          data << [
            _number_to_percentage(invoice.amount_percentage, precision: 1),
            _cur(invoice.amount - invoice.amount_before_percentage)]
        end

        if invoice.amount.positive? && @missing_amount != invoice.amount
          already_paid = invoice.amount - @missing_amount
          credit_amount = _cur(-(already_paid + invoice.member.credit_amount))
          unless invoice.memberships_amount?
            data << [t('total'), _cur_with_vat_appendice(invoice, invoice.amount)]
          end
          data << [t('credit_amount'), "#{appendice_star} #{credit_amount}"]
          data << [t('missing_amount'), _cur(@missing_amount)]
        elsif invoice.memberships_amount? && invoice.annual_fee?
          data << [t('total'), _cur(invoice.amount)]
        elsif invoice.entity_type != 'Membership'
          data << [t('total'), _cur_with_vat_appendice(invoice, invoice.amount)]
        end
      end

      move_down 30
      table data, column_widths: [bounds.width - 120, 70], position: :center do |t|
        t.cells.borders = []
        t.cells.valign = :bottom
        t.cells.align = :right
        t.cells.inline_format = true
        t.cells.leading = 1

        t.columns(0).padding_right = 15
        t.columns(1).padding_left = 0
        t.columns(1).padding_right = 0
        t.row(0).borders = [:bottom]
        t.row(0).font_style = :bold
        t.rows(2..-1).padding_top = 0

        if last_page

          t.columns(0).rows(1..-1).filter do |cell|
            if cell.content.in? [t('paid_memberships_amount'), t('credit_amount')]
              t.row(cell.row).font_style = :italic
            end
          end
          t.columns(1).rows(1..-1).filter do |cell|
            t.row(cell.row).font_style = :italic if cell.content == ''
          end

          row = -1
          if invoice.amount_percentage?
            row -= 2
            t.columns(1).rows(row).borders = [:top]
            t.row(row).padding_top = 0
            t.row(row - 1).padding_bottom = 10
          end

          if invoice.amount.positive? && @missing_amount != invoice.amount && invoice.entity_type != 'Membership'
            row -= 2
            t.columns(1).rows(row).borders = [:top]
            t.row(row).padding_top = 0
            t.row(row - 1).padding_bottom = 10
          end

          row = -1
          t.row(row).font_style = :bold
          if (@missing_amount != invoice.amount) || (invoice.memberships_amount? &&
              (invoice.annual_fee? || !invoice.memberships_amount_description?)) ||
              invoice.entity_type != 'Membership'
            t.columns(1).rows(row).borders = [:top]
            t.row(row).padding_top = 0
            t.row(row - 1).padding_bottom = 10
          end
          if invoice.memberships_amount_description?
            row -=
              if @missing_amount != invoice.amount
                invoice.annual_fee? ? 4 : 3
              else
                invoice.annual_fee? ? 3 : 1
              end

            t.columns(1).rows(row).borders = [:top]
            t.row(row).padding_top = 0
            t.row(row).padding_bottom = 15
            t.row(row - 1).padding_bottom = 10
          end
        end
      end

      return unless last_page

      if invoice.member.credit_amount.positive?
        move_down 5

        data = [[t('extra_credit'), _cur(invoice.member.credit_amount)]]
        table data, column_widths: [bounds.width - 120, 70], position: :center do |t|
          t.cells.borders = []
          t.cells.align = :right
          t.cells.font_style = :italic
          t.columns(0).padding_right = 15
          t.columns(1).padding_right = 0
        end
      end

      yy = 25
      reset_appendice_star

      if invoice.vat_amount&.positive?
        membership_vat_text = [
          "#{appendice_star} #{t('all_taxes_included')}",
          "#{_cur(invoice.amount_without_vat, unit: true)} #{t('without_taxes')}",
          "#{_cur(invoice.vat_amount, unit: true)} #{t('vat')} (#{invoice.vat_rate}%)"
        ].join(', ')
        bounding_box [0, y - 25], width: bounds.width - 24 do
          text membership_vat_text, width: 200, align: :right, style: :italic, size: 9
        end
        bounding_box [0, y - 5], width: bounds.width - 24 do
          text "N° #{t('vat')} #{Current.acp.vat_number}", width: 200, align: :right, style: :italic, size: 9
        end
        yy = 10
      end

      if invoice.amount.positive? && @missing_amount != invoice.amount
        credit_amount_text = "#{appendice_star} #{t('credit_amount_text')}"
        bounding_box [0, y - yy], width: bounds.width - 24 do
          text credit_amount_text, width: 200, align: :right, style: :italic, size: 9, leading: 1.5
        end
        yy = 10
      end

      bounding_box [0, y - yy - 10], width: bounds.width - 24 do
        invoice_info =
          if invoice.entity_type == 'Shop::Order' && Current.acp.shop_invoice_info
            Current.acp.shop_invoice_info % {
              date: I18n.l(invoice.entity.delivery.date)
            }
          else Current.acp.invoice_info
          end
        text invoice_info, width: 200, align: :right, style: :italic, size: 9
      end
    end

    def footer(last_page:)
      y = last_page ? 320 : 40
      font_size 10
      bounding_box [0, y], width: bounds.width, height: 50 do
        text Current.acp.invoice_footer, inline_format: true, align: :center
      end
    end

    def qr
      y = 320
      border = 13
      font_size 8
      bounding_box [0, y], width: bounds.width - border, height: y do
        qr_borders
        qr_receipt(border)
        qr_payment_part(border)
      end
    end

    def qr_borders
      stroke do
        move_down 22
        dash(1, space: 2.6, phase: 0)
        line_width 0.5
        horizontal_line(-2.1, 600)
      end
      rotate 180, origin: [300, 300] do
        image "#{Rails.root}/lib/assets/images/scissor.png",
          at: [27, 305.65],
          width: 12
      end
      stroke do
        dash(1, space: 2.6, phase: 0)
        line_width 0.5
        stroke_vertical_line([176.66, 0], nil, at: [176.66, 296.5])
      end
      rotate 90, origin: [100, 100] do
        image "#{Rails.root}/lib/assets/images/scissor.png",
          at: [22.9, 26.92],
          width: 12
      end
    end

    def qr_receipt(border)
      bounding_box [border, 298 - border], width: 145, height: 298 - 2 * border do
        qr_text_main_title t('qr_bill.receipt')
        move_down border

        qr_text_title t('qr_bill.payable_to'), size: 6
        qr_text format_iban(Current.acp.qr_iban), size: 8
        qr_text Current.acp.qr_creditor_name, size: 8
        qr_text Current.acp.qr_creditor_address, size: 8
        qr_text Current.acp.qr_creditor_zip + ' ' + Current.acp.qr_creditor_city, size: 8
        move_down border

        qr_text_title t('qr_bill.reference'), size: 6
        qr_text QRReferenceNumber.new(invoice).formatted_ref, size: 8
        move_down border

        qr_text_title t('qr_bill.payable_by'), size: 6
        qr_text invoice.member.name.truncate(70), size: 8
        qr_text invoice.member.address.truncate(70), size: 8
        qr_text invoice.member.zip + ' ' + invoice.member.city, size: 8

        bounding_box [0, 98], width: 200 do
          qr_text_title t('qr_bill.currency'), size: 6
          qr_text Current.acp.currency_code, size: 8
        end
        bounding_box [65, 98], width: 200 do
          qr_text_title t('qr_bill.amount'), size: 6
          qr_text _cur(@missing_amount, delimiter: ' '), size: 8
        end

        bounding_box [105, 48], width: 200 do
          qr_text_title t('qr_bill.acceptance_point'), size: 6
        end
      end
    end

    def qr_payment_part(border)
      bounding_box [176.66 + border, 298 - border], width: 390, height: 298 - 2 * border do
        qr_text_main_title t('qr_bill.payment_part')

        image InvoiceQRCode.new(invoice).generate_qr_image.path,
          at: [-2.5, 252],
          width: 137

        bounding_box [0, 100], width: 200 do
          qr_text_title t('qr_bill.currency')
          qr_text Current.acp.currency_code
        end
        bounding_box [65, 100], width: 200 do
          qr_text_title t('qr_bill.amount')
          qr_text _cur(@missing_amount, delimiter: ' ')
        end

        bounding_box [146, 270], width: 230 do
          qr_text_title t('qr_bill.payable_to')
          qr_text format_iban(Current.acp.qr_iban)
          qr_text Current.acp.qr_creditor_name
          qr_text Current.acp.qr_creditor_address
          qr_text Current.acp.qr_creditor_zip + ' ' + Current.acp.qr_creditor_city
          move_down border

          qr_text_title t('qr_bill.reference')
          qr_text QRReferenceNumber.new(invoice).formatted_ref
          move_down border

          qr_text_title t('qr_bill.further_information')
          qr_text "#{::Invoice.model_name.human} #{invoice.id}"
          move_down border

          qr_text_title t('qr_bill.payable_by')
          qr_text invoice.member.name.truncate(70)
          qr_text invoice.member.address.truncate(70)
          qr_text invoice.member.zip + ' ' + invoice.member.city
        end
      end
    end

    def qr_text_main_title(txt, **options)
      text txt, {
        size: 11,
        character_spacing: 0.4,
        style: :bold
      }.merge(options)
    end

    def qr_text_title(txt, **options)
      text txt, {
        size: 8,
        character_spacing: 0.4,
        style: :bold
      }.merge(options)
      move_down 3
    end

    def qr_text(txt, **options)
      text txt, {
        size: 10,
        character_spacing: 0.4,
        style: :normal
      }.merge(options)
      move_down 1.5
    end

    def appendice_star
      @stars_count ||= 0
      @stars_count += 1
      '*' * @stars_count
    end

    def format_iban(iban)
      iban
        .delete(' ')
        .gsub(/(.{4})(?=.)/, '\1 \2')
    end

    def reset_appendice_star
      @stars_count = nil
    end

    def membership_basket_size_description(basket_size)
      baskets = entity.baskets.where(basket_size: basket_size)
      "#{Basket.model_name.human}: #{basket_size.public_name} #{basket_sizes_price_info(entity, baskets)}"
    end

    def membership_baskets_price_extra_description
      title = Current.acp.basket_price_extra_public_title
      "#{title}: #{baskets_price_extra_info(entity, entity.baskets)}"
    end

    def membership_basket_complement_description(basket_complement)
      "#{basket_complement.public_name}: #{basket_complement_price_info(entity, basket_complement)}"
    end

    def membership_depot_description(depot)
      baskets = entity.baskets.where(depot: depot)
      "#{Depot.model_name.human}: #{depot.public_name} #{depots_price_info(baskets)}"
    end

    def activity_participations_annual_price_change_description
      i18n_scope = Current.acp.activity_i18n_scope
      diff = entity.activity_participations_demanded_annualy - entity.basket_size.activity_participations_demanded_annualy
      if diff.positive?
        Membership.human_attribute_name("activity_participations_annual_price_change_reduction/#{i18n_scope}", count: diff)
      elsif diff.negative?
        Membership.human_attribute_name("activity_participations_annual_price_change_negative/#{i18n_scope}", count: diff)
      elsif entity.activity_participations_annual_price_change.positive?
        Membership.human_attribute_name("activity_participations_annual_price_change_positive/#{i18n_scope}")
      else
        Membership.human_attribute_name("activity_participations_annual_price_change_default/#{i18n_scope}")
      end
    end

    def _cur(amount, unit: false, **options)
      cur(amount, unit: unit, **options)
    end

    def _cur_with_vat_appendice(invoice, amount, unit: false, **options)
      amount = _cur(amount).to_s
      if invoice.vat_amount&.positive?
        "#{appendice_star}#{amount}"
      else
        amount
      end
    end

    def t(key, **args)
      I18n.t("invoices.pdf.#{key}", **args)
    end

    def t_activity(key, **args)
      super(key, **args)
    end
  end
end
