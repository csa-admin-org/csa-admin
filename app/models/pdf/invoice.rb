module PDF
  class Invoice < Base
    include ActivitiesHelper
    include MembershipsHelper
    include NumbersHelper

    attr_reader :invoice, :object

    def initialize(invoice)
      @invoice = invoice
      @object = invoice.object
      # Reload object to be sure that the balance is up-to-date
      @missing_amount = ::Invoice.find(invoice.id).missing_amount
      super
      header
      member_address
      content
      footer
      bill
    end

    private

    def info
      super.merge(Title: "#{::Invoice.model_name.human} #{invoice.id}")
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

    def header
      image acp_logo_io, at: [15, bounds.height - 20], width: 110
      bounding_box [155, bounds.height - 55], width: 200, height: 2.6.cm do
        text "#{::Invoice.model_name.human} N° #{invoice.id}", style: :bold, size: 16
        move_down 5
        text I18n.l(invoice.date)
        case invoice.object_type
        when 'Membership'
          move_down 5
          text membership_short_period(object), size: 10
        when 'Shop::Order'
          move_down 12
          text "#{::Shop::Order.model_name.human} N° #{object.id}"
          move_down 5
          text "#{::Delivery.model_name.human}: #{I18n.l(object.delivery.date)}"
        end
      end
    end

    def content
      font_size 10
      data = [[
        ::Invoice.human_attribute_name(:description),
        "#{::Invoice.human_attribute_name(:amount)} (#{currency_symbol})"
      ]]

      case invoice.object_type
      when 'Membership'
        if object.basket_sizes_price.positive?
          object.basket_sizes.uniq.each do |basket_size|
            data << [
              membership_basket_size_description(basket_size),
              _cur(object.basket_size_price(basket_size))
            ]
          end
        end
        if Current.acp.feature?('basket_price_extra') && object.baskets_extra_price.positive?
          data << [
            membership_baskets_extra_price_description,
            _cur(object.baskets_extra_price)
          ]
        end
        unless object.baskets_annual_price_change.zero?
          data << [
            t('baskets_annual_price_change'),
            _cur(object.baskets_annual_price_change)
          ]
        end
        if object.basket_complements_price.positive?
          basket_complements = (
            object.basket_complements + object.subscribed_basket_complements
          ).uniq
          basket_complements.each do |basket_complement|
            data << [
              membership_basket_complement_description(basket_complement),
              _cur(object.basket_complement_total_price(basket_complement))
            ]
          end
        end
        unless object.basket_complements_annual_price_change.zero?
          data << [
            t('basket_complements_annual_price_change'),
            _cur(object.basket_complements_annual_price_change)
          ]
        end
        object.depots.uniq.each do |depot|
          price = object.depot_total_price(depot)
          if price.positive?
            data << [
              membership_depot_description(depot),
              _cur(price)
            ]
          end
        end
        unless object.activity_participations_annual_price_change.zero?
          data << [activity_participations_annual_price_change_description, _cur(object.activity_participations_annual_price_change)]
        end
      when 'ActivityParticipation'
        if object
          str = t_activity('missed_activity_participation_with_date', date: I18n.l(object.activity.date))
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
      when 'Other', 'GroupBuying::Order', 'Shop::Order'
        invoice.items.each do |item|
          data << [item.description, _cur(item.amount)]
        end
      end

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
        gross_amount = _cur(invoice.memberships_amount).to_s
        gross_amount = "#{appendice_star}#{gross_amount}" if invoice.memberships_vat_amount&.positive?
        data << [invoice.memberships_amount_description, gross_amount]
      end

      if invoice.annual_fee?
        data << [t('annual_fee'), _cur(invoice.annual_fee)]
      end

      if invoice.amount.positive? && @missing_amount != invoice.amount
        already_paid = invoice.amount - @missing_amount
        credit_amount = _cur(-(already_paid + invoice.member.credit_amount))
        data << [t('credit_amount'), "#{appendice_star} #{credit_amount}"]
        data << [t('missing_amount'), _cur(@missing_amount)]
      elsif (invoice.memberships_amount? && invoice.annual_fee?) || invoice.object_type != 'Membership'
        data << [t('total'), _cur(invoice.amount)]
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

        t.columns(0).rows(1..-1).filter do |cell|
          if cell.content.in? [t('paid_memberships_amount'), t('credit_amount')]
            t.row(cell.row).font_style = :italic
          end
        end
        t.columns(1).rows(1..-1).filter do |cell|
          t.row(cell.row).font_style = :italic if cell.content == ''
        end

        row = -1
        t.row(row).font_style = :bold

        if (@missing_amount != invoice.amount) || (invoice.memberships_amount? &&
            (invoice.annual_fee? || !invoice.memberships_amount_description?)) ||
            invoice.object_type != 'Membership'
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

      if invoice.memberships_vat_amount&.positive?
        membership_vat_text = [
          "#{appendice_star} #{t('all_taxes_included')}",
          "#{_cur(invoice.memberships_net_amount, unit: true)} #{t('without_taxes')}",
          "#{_cur(invoice.memberships_vat_amount, unit: true)} #{t('vat')} (#{Current.acp.vat_membership_rate}%)"
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

      bounding_box [0, y - yy - 20], width: bounds.width - 24 do
        invoice_info =
          if invoice.object_type == 'GroupBuying::Order' && Current.acp.group_buying_invoice_info
            Current.acp.group_buying_invoice_info % {
              date: I18n.l(invoice.object.delivery.orderable_until)
            }
          elsif invoice.object_type == 'Shop::Order' && Current.acp.shop_invoice_info
            Current.acp.shop_invoice_info % {
              date: I18n.l(invoice.object.delivery.date)
            }
          else Current.acp.invoice_info
          end
        text invoice_info, width: 200, align: :right, style: :italic, size: 9
      end
    end

    def footer
      font_size 10
      y = Current.acp.invoice_type == 'ISR' ? 300 : 320
      bounding_box [0, y], width: bounds.width, height: 50 do
        text Current.acp.invoice_footer, inline_format: true, align: :center
      end
    end

    def bill
      case Current.acp.invoice_type
      when 'QR'; qr
      when 'ISR'; isr
      end
    end

    def isr
      y = 273
      font_size 8
      isr_ref = ISRReferenceNumber.new(invoice.id, @missing_amount)
      bounding_box [0, y], width: bounds.width, height: y do
        image "#{Rails.root}/lib/assets/images/isr.jpg",
          at: [0, y],
          width: bounds.width
        [10, 185].each do |x|
          text_box Current.acp.isr_payment_for, at: [x, y - 25], width: 120, height: 50, leading: 2
          text_box Current.acp.isr_in_favor_of, at: [x, y - 62], width: 120, height: 50, leading: 2
          text_box "N° #{::Invoice.model_name.human}: #{invoice.id}",
            at: [x, y - 108],
            width: 120,
            height: 50
        end
        font('OcrB')
        [87, 260].each do |x|
          text_box Current.acp.ccp,
            at: [x, y - 120],
            width: 100,
            height: 50,
            size: 10.5,
            character_spacing: 1
        end
        [64, 238].each do |x|
          text_box isr_ref.amount_without_cents,
            at: [x, y - 145],
            width: 50,
            height: 50,
            character_spacing: 1,
            size: 12,
            align: :right
          text_box isr_ref.amount_cents,
            at: [x + 75, y - 145],
            width: 50,
            height: 50,
            size: 12,
            character_spacing: 1
        end
        text_box isr_ref.ref,
          at: [353, y - 97],
          width: 370,
          height: 50,
          size: 10.5,
          character_spacing: 1
        text_box isr_ref.full_ref,
          at: [185, y - 241],
          width: 390,
          height: 50,
          size: 10.5,
          align: :right,
          character_spacing: 1
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
        qr_text QRReferenceNumber.new(invoice.id).formatted_ref, size: 8
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
          qr_text QRReferenceNumber.new(invoice.id).formatted_ref
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
      baskets = object.baskets.where(basket_size: basket_size)
      "#{Basket.model_name.human}: #{basket_size.public_name} #{basket_sizes_price_info(object, baskets)}"
    end

    def membership_baskets_extra_price_description
      "#{Current.acp.basket_price_extra_public_title} #{baskets_extra_price_info(object)}"
    end

    def membership_basket_complement_description(basket_complement)
      "#{basket_complement.public_name} #{basket_complement_price_info(object, basket_complement)}"
    end

    def membership_depot_description(depot)
      baskets = object.baskets.where(depot: depot)
      "#{Depot.model_name.human}: #{depot.public_name} #{depots_price_info(baskets)}"
    end

    def activity_participations_annual_price_change_description
      i18n_scope = Current.acp.activity_i18n_scope
      diff = object.activity_participations_demanded_annualy - object.basket_size.activity_participations_demanded_annualy
      if diff.positive?
        Membership.human_attribute_name("activity_participations_annual_price_change_reduction/#{i18n_scope}", count: diff)
      elsif diff.negative?
        Membership.human_attribute_name("activity_participations_annual_price_change_negative/#{i18n_scope}", count: diff)
      elsif object.activity_participations_annual_price_change.positive?
        Membership.human_attribute_name("activity_participations_annual_price_change_positive/#{i18n_scope}")
      else
        Membership.human_attribute_name("activity_participations_annual_price_change_default/#{i18n_scope}")
      end
    end

    def _cur(amount, unit: false, **options)
      cur(amount, unit: unit, **options)
    end

    def t(key, **args)
      I18n.t("invoices.pdf.#{key}", **args)
    end

    def t_activity(key, **args)
      super(key, **args)
    end
  end
end
