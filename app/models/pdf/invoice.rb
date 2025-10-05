# frozen_string_literal: true

module PDF
  class Invoice < Base
    include ActivitiesHelper
    include MembershipsHelper
    include NumbersHelper

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
      items_per_full_page = 40.0
      max_items_on_last_page = Current.org.swiss_qr? ? 10 : 15

      if items.size > max_items_on_last_page
        first_items = items.first(items.size - max_items_on_last_page)
        first_total_pages = (first_items.size / items_per_full_page.to_f).ceil
        items_per_page = (first_items.size / (first_total_pages).to_f).ceil
        first_items.each_slice(items_per_page).with_index do |items_slice, i|
          page(items_slice, page: i + 1, total_pages: first_total_pages + 1)
        end

        total_pages = first_total_pages + 1
        last_items = items.last(max_items_on_last_page)
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
      last_page ? payment_section : start_new_page
    end

    def info
      super.merge(Title: "#{invoice.document_name} #{invoice.id}")
    end

    def header(page:, total_pages:)
      image org_logo_io(size: 110), at: [ 15, bounds.height - 20 ], width: 110
      bounding_box [ 155, bounds.height - 1.5.cm ], width: 6.5.cm, height: 3.cm do
        text "#{invoice.document_name} N°\u00A0#{invoice.id}", style: :bold, size: 16, leading: 3
        move_down 5
        text I18n.l(invoice.date)
        case invoice.entity_type
        when "Membership"
          move_down 5
          text membership_period(entity, format: :number), size: 10
        when "Shop::Order"
          move_down 12
          text "#{::Shop::Order.model_name.human} N°\u00A0#{entity.id}"
          move_down 5
          text "#{::Delivery.model_name.human}: #{I18n.l(entity.delivery.date)}"
        end
      end
      member_address_and_id

      if total_pages > 1
        bounding_box [ bounds.width - 65, bounds.height - 30 ], width: 50, height: 50 do
          text "#{page} / #{total_pages}", align: :center, style: :bold, size: 16
        end
        move_down 40
      end
    end

    def member_address_and_id
      member = invoice.member
      parts = [
        member.billing_info(:name).truncate(70),
        member.billing_info(:address).truncate(70),
        "#{member.billing_info(:zip)} #{member.billing_info(:city)}"
      ]

      bounding_box [ 12.15.cm, bounds.height - 1.5.cm ], width: 7.8.cm, height: 3.cm do
        parts.each do |part|
          text part, valign: :top, leading: 2, align: :right
          move_down 2
        end
        move_down 10
        text t(".member_id", id: member.id), valign: :top, leading: 2, align: :right, size: 10
        if invoice.share_type? && invoice.member.shares_info?
          move_down 2
          attr_name = Member.human_attribute_name(:shares_info)
          text "#{attr_name}: #{invoice.member.shares_info}", valign: :top, leading: 2, align: :right, size: 10
        end
      end
    end

    def content(items, last_page:)
      font_size 10
      data = [ [
        ::Invoice.human_attribute_name(:description),
        "#{::Invoice.human_attribute_name(:amount)} (#{currency_symbol})"
      ] ]

      case invoice.entity_type
      when "Membership"
        if entity.basket_sizes_price.positive?
          entity.basket_sizes.uniq.each do |basket_size|
            data << [
              membership_basket_size_description(basket_size),
              cur(entity.basket_size_total_price(basket_size))
            ]
          end
        end
        unless entity.baskets_annual_price_change.zero?
          data << [
            t("baskets_annual_price_change"),
            cur(entity.baskets_annual_price_change)
          ]
        end
        if entity.basket_complements_price.positive?
          basket_complements = (
            entity.basket_complements + entity.subscribed_basket_complements
          ).uniq
          basket_complements.each do |basket_complement|
            data << [
              membership_basket_complement_description(basket_complement),
              cur(entity.basket_complement_total_price(basket_complement))
            ]
          end
        end
        unless entity.basket_complements_annual_price_change.zero?
          data << [
            t("basket_complements_annual_price_change"),
            cur(entity.basket_complements_annual_price_change)
          ]
        end
        if Current.org.feature?("basket_price_extra") && !entity.baskets_price_extra.zero?
          data << [
            membership_baskets_price_extra_description,
            cur(entity.baskets_price_extra)
          ]
        end
        entity.depots.uniq.each do |depot|
          price = entity.depot_total_price(depot)
          if price.positive?
            data << [
              membership_depot_description(depot),
              cur(price)
            ]
          end
        end
        if entity.deliveries_price.positive?
          data << [
            membership_deliveries_description,
            cur(entity.deliveries_price)
          ]
        end
        unless entity.activity_participations_annual_price_change.zero?
          data << [ activity_participations_annual_price_change_description, cur(entity.activity_participations_annual_price_change) ]
        end
      when "ActivityParticipation"
        if entity
          str = t_activity("missed_activity_participation_with_date", date: I18n.l(entity.activity.date))
          if invoice.missing_activity_participations_count > 1
            str += " (#{invoice.missing_activity_participations_count} #{ActivityParticipation.human_attribute_name(:participants).downcase})"
          end
        elsif invoice.missing_activity_participations_count == 1
          str = t_activity("missed_activity_participation",
            year: invoice.missing_activity_participations_fiscal_year)
        else
          str = t_activity("missed_activity_participations",
            year: invoice.missing_activity_participations_fiscal_year,
            count: invoice.missing_activity_participations_count)
        end
        data << [ str, cur(invoice.amount) ]
      when "Share"
        str =
          if invoice.shares_number.positive?
            t("shares_number", count: invoice.shares_number)
          else
            t("shares_number_negative", count: invoice.shares_number.abs)
          end
        data << [ str, cur(invoice.amount) ]
      when "Other", "Shop::Order", "NewMemberFee"
        items.each do |item|
          data << [ item.description, cur(item.amount) ]
        end
      end

      if last_page
        if invoice.paid_memberships_amount.to_f.positive?
          data << [
            t("paid_memberships_amount"),
            cur(-invoice.paid_memberships_amount)
          ]
          data << [
            t("remaining_annual_memberships_amount"),
            cur(invoice.remaining_memberships_amount)
          ]
        elsif invoice.remaining_memberships_amount?
          data << [
            t("annual_memberships_amount"),
            cur(invoice.remaining_memberships_amount)
          ]
        end

        if invoice.memberships_amount?
          data << [
            invoice.memberships_amount_description,
            cur_with_vat_appendice(invoice, invoice.memberships_amount)
          ]
        end

        if invoice.annual_fee?
          data << [ t("annual_fee"), cur(invoice.annual_fee) ]
        end

        if invoice.amount_percentage?
          data << [ t("total_before_percentage"), cur(invoice.amount_before_percentage) ]
          data << [
            _number_to_percentage(invoice.amount_percentage, precision: 1),
            cur(invoice.amount - invoice.amount_before_percentage) ]
        end

        if invoice.amount.positive? && @missing_amount != invoice.amount
          already_paid = invoice.amount - @missing_amount
          credit_amount = cur(-(already_paid + invoice.member.credit_amount))
          unless invoice.memberships_amount?
            data << [ t("total"), cur_with_vat_appendice(invoice, invoice.amount) ]
          end
          data << [ t("credit_amount"), "#{appendice_star} #{credit_amount}" ]
          data << [ t("missing_amount"), cur(@missing_amount) ]
        elsif invoice.memberships_amount? && invoice.annual_fee?
          data << [ t("total"), cur(invoice.amount) ]
        elsif invoice.entity_type != "Membership"
          data << [ t("total"), cur_with_vat_appendice(invoice, invoice.amount) ]
        end
      end

      move_down 30
      table data, column_widths: [ bounds.width - 120, 70 ], position: :center do |t|
        t.cells.borders = []
        t.cells.valign = :bottom
        t.cells.align = :right
        t.cells.inline_format = true
        t.cells.leading = 1

        t.columns(0).padding_right = 15
        t.columns(1).padding_left = 0
        t.columns(1).padding_right = 0
        t.row(0).borders = [ :bottom ]
        t.row(0).font_style = :bold
        t.rows(2..-1).padding_top = 0

        if last_page

          t.columns(0).rows(1..-1).filter do |cell|
            if cell.content.in? [ t("paid_memberships_amount"), t("credit_amount") ]
              t.row(cell.row).font_style = :italic
            end
          end
          t.columns(1).rows(1..-1).filter do |cell|
            t.row(cell.row).font_style = :italic if cell.content == ""
          end

          row = -1
          if invoice.amount_percentage?
            row -= 2
            t.columns(1).rows(row).borders = [ :top ]
            t.row(row).padding_top = 0
            t.row(row - 1).padding_bottom = 10
          end

          if invoice.amount.positive? && @missing_amount != invoice.amount && invoice.entity_type != "Membership"
            row -= 2
            t.columns(1).rows(row).borders = [ :top ]
            t.row(row).padding_top = 0
            t.row(row - 1).padding_bottom = 10
          end

          row = -1
          t.row(row).font_style = :bold
          if (@missing_amount != invoice.amount) || (invoice.memberships_amount? &&
              (invoice.annual_fee? || !invoice.memberships_amount_description?)) ||
              invoice.entity_type != "Membership"
            t.columns(1).rows(row).borders = [ :top ]
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

            t.columns(1).rows(row).borders = [ :top ]
            t.row(row).padding_top = 0
            t.row(row).padding_bottom = 15
            t.row(row - 1).padding_bottom = 10
          end
        end
      end

      return unless last_page

      if invoice.member.credit_amount.positive?
        move_down 5

        data = [ [ t("extra_credit"), cur(invoice.member.credit_amount) ] ]
        table data, column_widths: [ bounds.width - 120, 70 ], position: :center do |t|
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
          "#{cur(invoice.amount_without_vat, unit: true)} #{t("without_taxes")}",
          "#{cur(invoice.vat_amount, unit: true)} #{t("vat")} (#{invoice.vat_rate}%)"
        ].join(", ")
        bounding_box [ 0, y - 25 ], width: bounds.width - 24 do
          text membership_vat_text, width: 200, align: :right, style: :italic, size: 9
        end
        bounding_box [ 0, y - 5 ], width: bounds.width - 24 do
          text "N° #{t("vat")} #{Current.org.vat_number}", width: 200, align: :right, style: :italic, size: 9
        end
        yy = 10
      end

      if invoice.amount.positive? && @missing_amount != invoice.amount
        credit_amount_text = "#{appendice_star} #{t("credit_amount_text")}"
        bounding_box [ 0, y - yy ], width: bounds.width - 24 do
          text credit_amount_text, width: 200, align: :right, style: :italic, size: 9, leading: 1.5
        end
        yy = 10
      end

      replacing_ids = invoice.previously_canceled_entity_invoice_ids
      if replacing_ids.present?
        replacing_text = if replacing_ids.many?
          t("replacing_invoices", ids: replacing_ids.to_sentence)
        else
          t("replacing_invoice", id: replacing_ids.first)
        end

        bounding_box [ 0, y - yy - 10 ], width: bounds.width - 24 do
          text replacing_text, width: 200, align: :right, style: :italic, size: 9
        end
        yy = 0
      end

      bounding_box [ 0, y - yy - 10 ], width: bounds.width - 24 do
        if invoice.entity_type == "Shop::Order" && Current.org.shop_invoice_info
          shop_invoice_info = Current.org.shop_invoice_info % {
            date: I18n.l(invoice.entity.delivery.date)
          }
          text shop_invoice_info, width: 200, align: :right, style: :italic, size: 9
          move_down 10
        end

        invoice_info = invoice.sepa? ? Current.org.invoice_sepa_info : Current.org.invoice_info
        text invoice_info, width: 200, align: :right, style: :italic, size: 9
      end
    end

    def footer(last_page:)
      y = last_page ? payment_section_y : 40

      x_position = 15
      Current.org.invoice_logos.each do |invoice_logo|
        begin
          logo = invoice_logo.variant(resize_to_limit: [ 135, 135 ]).processed.download
          image_info = Vips::Image.new_from_buffer(logo, "")
          logo_io = StringIO.new(logo)
          aspect_ratio = image_info.width.to_f / image_info.height
          target_height = 45
          target_width = target_height * aspect_ratio
          image logo_io, at: [ x_position, y + 65 ], width: target_width, height: target_height
          x_position += target_width + 15 # Move to next logo with spacing
        rescue Vips::Error => e
          Rails.logger.error "Failed to process logo ID #{invoice_logo.id}: #{e.message}"
          next
        end
      end

      font_size 10
      lines = Current.org.invoice_footer&.lines&.size.to_i
      height = lines * 25
      bounding_box [ 0, y + (lines - 1) * 10 ], width: bounds.width, height: height do
        text Current.org.invoice_footer, inline_format: true, align: :center, leading: 3
      end
    end

    def payment_section
      y = payment_section_y
      border = 13
      font_size 8
      bounding_box [ 0, y ], width: bounds.width - border, height: y do
        if Current.org.swiss_qr?
          swiss_qr(border)
        elsif Current.org.sepa?
          if invoice.sepa_metadata.present?
            payment_info(border)
          else
            epc_qr(border)
          end
        else payment_info(border)
        end
      end
    end

    def payment_section_y
      Current.org.swiss_qr? ? 320 : 220
    end

    ## Swiss QR

    def swiss_qr(border)
      swiss_qr_borders
      swiss_qr_receipt(border)
      swiss_qr_payment_part(border)
    end

    def swiss_qr_borders
      stroke do
        move_down 22
        dash(1, space: 2.6, phase: 0)
        line_width 0.5
        horizontal_line(-2.1, 600)
      end
      rotate 180, origin: [ 300, 300 ] do
        image "#{Rails.root}/lib/assets/images/scissor.png",
          at: [ 27, 305.65 ],
          width: 12
      end
      stroke do
        dash(1, space: 2.6, phase: 0)
        line_width 0.5
        stroke_vertical_line([ 176.66, 0 ], nil, at: [ 176.66, 296.5 ])
      end
      rotate 90, origin: [ 100, 100 ] do
        image "#{Rails.root}/lib/assets/images/scissor.png",
          at: [ 22.9, 26.92 ],
          width: 12
      end
    end

    def swiss_qr_receipt(border)
      bounding_box [ border, 298 - border ], width: 145, height: 298 - 2 * border do
        qr_text_main_title t("payment.receipt")
        move_down border

        qr_text_title t("payment.payable_to_account"), size: 6
        qr_text Current.org.iban_formatted, size: 8
        qr_text Current.org.creditor_name, size: 8
        qr_text Current.org.creditor_address, size: 8
        qr_text Current.org.creditor_zip + " " + Current.org.creditor_city, size: 8
        move_down border

        qr_text_title t("payment.reference"), size: 6
        qr_text invoice.reference.formatted, size: 8
        move_down border

        qr_text_title t("payment.payable_by"), size: 6
        qr_text invoice.member.billing_info(:name).truncate(70), size: 8
        qr_text invoice.member.billing_info(:address).truncate(70), size: 8
        qr_text invoice.member.billing_info(:zip) + " " + invoice.member.billing_info(:city), size: 8

        bounding_box [ 0, 98 ], width: 200 do
          qr_text_title t("payment.currency"), size: 6
          qr_text Current.org.currency_code, size: 8
        end
        bounding_box [ 65, 98 ], width: 200 do
          qr_text_title t("payment.amount"), size: 6
          qr_text cur(@missing_amount, delimiter: " "), size: 8
        end

        bounding_box [ 105, 48 ], width: 200 do
          qr_text_title t("payment.acceptance_point"), size: 6
        end
      end
    end

    def swiss_qr_payment_part(border)
      bounding_box [ 176.66 + border, 298 - border ], width: 390, height: 298 - 2 * border do
        qr_text_main_title t("payment.payment_part")

        image Billing::SwissQRCode.generate(invoice),
          at: [ -2.5, 252 ],
          width: 137

        bounding_box [ 0, 100 ], width: 200 do
          qr_text_title t("payment.currency")
          qr_text Current.org.currency_code
        end
        bounding_box [ 65, 100 ], width: 200 do
          qr_text_title t("payment.amount")
          qr_text cur(@missing_amount, delimiter: " ")
        end

        bounding_box [ 146, 270 ], width: 230 do
          qr_text_title t("payment.payable_to_account")
          qr_text Current.org.iban_formatted
          qr_text Current.org.creditor_name
          qr_text Current.org.creditor_address
          qr_text Current.org.creditor_zip + " " + Current.org.creditor_city
          move_down border

          qr_text_title t("payment.reference")
          qr_text invoice.reference.formatted
          move_down border

          qr_text_title t("payment.further_information")
          qr_text "#{invoice.document_name} #{invoice.id}"
          move_down border

          qr_text_title t("payment.payable_by")
          qr_text invoice.member.billing_info(:name).truncate(70)
          qr_text invoice.member.billing_info(:address).truncate(70)
          qr_text invoice.member.billing_info(:zip) + " " + invoice.member.billing_info(:city)
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

    ## EPC QR

    def epc_qr(border)
      payment_info_border(2 * border)
      bounding_box [ 2 * border, payment_section_y - 35 ], width: 570, height: payment_section_y do
        qr_text_main_title t("payment.payment_part")
        y_start = bounds.height - 25

        qr_code_width = 110
        svg Billing::EPCQRCode.generate(invoice),
          at: [ 0, y_start ],
          width: qr_code_width

        bounding_box [ 0, y_start - qr_code_width - 12 ], width: qr_code_width do
          text t("payment.pay_with_code"), size: 10, align: :center
        end

        spacing = 9
        bounding_box [ qr_code_width + 16, y_start ], width: 300 do
          qr_text_title "IBAN"
          qr_text Current.org.iban_formatted
          move_down spacing

          qr_text_title t("payment.payable_to")
          qr_text Current.org.creditor_name
          move_down spacing

          qr_text_title t("payment.reference_number")
          qr_text invoice.reference.formatted
          move_down spacing

          qr_text_title t("payment.amount")
          qr_text [ Current.org.currency_code, cur(@missing_amount, delimiter: " ") ].join(" ")
        end
      end
    end

    ## Other countries

    def payment_info(border)
      border = 2 * border
      payment_info_border(border)
      bounding_box [ border, payment_section_y - 40 ], width: 570, height: payment_section_y do
        title = invoice.sepa? ? t("payment.sepa_direct_debit") : t("payment.payment_part")
        payment_info_text title, size: 12, style: :bold
        y_start = bounds.height - 28
        x_split = bounds.width / 2

        bounding_box [ 0, y_start ], width: x_split - 30 do
          payment_info_title t("payment.amount")
          payment_info_text [ Current.org.currency_code, cur(@missing_amount, delimiter: " ") ].join(" "), size: 14
          move_down 10

          payment_info_title t("payment.payable_to")
          payment_info_text Current.org.creditor_name
          payment_info_text Current.org.creditor_address
          payment_info_text Current.org.creditor_zip + " " + Current.org.creditor_city
          move_down 5
          payment_info_text "IBAN: <b>#{Current.org.iban_formatted}</b>"
          if invoice.sepa?
            payment_info_text "#{t("payment.sepa_creditor_identifier")}: <b>#{Current.org.sepa_creditor_identifier}</b>"
          end
        end
        bounding_box [ x_split, y_start ], width: x_split do
          payment_info_title t("payment.reference_number")
          payment_info_text invoice.reference.formatted, size: 14
          move_down 10

          payment_info_title t("payment.payable_by")
          if invoice.sepa?
            payment_info_text invoice.sepa_metadata["name"].truncate(70)
            payment_info_text invoice.member.billing_info(:address).truncate(70)
            payment_info_text invoice.member.billing_info(:zip) + " " + invoice.member.billing_info(:city)

            move_down 5
            payment_info_text "IBAN: <b>#{invoice.sepa_metadata["iban"].scan(/.{1,4}/)&.join(" ")}</b>"
            mandate_signed_on = Date.parse(invoice.sepa_metadata["mandate_signed_on"])
            payment_info_text "#{t("payment.sepa_mandate_id")}: <b>#{invoice.sepa_metadata["mandate_id"]}</b> (#{I18n.l(mandate_signed_on, format: :short)})"
          else
            payment_info_text invoice.member.billing_info(:name).truncate(70)
            payment_info_text invoice.member.billing_info(:address).truncate(70)
            payment_info_text invoice.member.billing_info(:zip) + " " + invoice.member.billing_info(:city)
          end
        end
      end
    end

    def payment_info_border(border)
      stroke do
        move_down 22
        line_width 0.5
        dash(1, space: 2.5, phase: 0)
        horizontal_line(border, 570)
      end
    end

    def payment_info_title(txt)
      payment_info_text(txt, size: 9, style: :bold, down: 7)
    end

    def payment_info_text(txt, **options)
      down = options.delete(:down) || 3
      text txt, {
        size: 10,
        character_spacing: 0.4,
        style: :normal,
        inline_format: true
      }.merge(options)
      move_down down
    end

    ## Common

    def appendice_star
      @stars_count ||= 0
      @stars_count += 1
      "*" * @stars_count
    end

    def reset_appendice_star
      @stars_count = nil
    end

    def membership_basket_size_description(basket_size)
      baskets = entity.baskets.where(basket_size: basket_size)
      "#{Basket.model_name.human}: #{basket_size.public_name} #{basket_sizes_price_info(entity, baskets)}"
    end

    def membership_baskets_price_extra_description
      title = Current.org.basket_price_extra_public_title
      "#{title}: #{baskets_price_extra_info(entity, entity.baskets)}"
    end

    def membership_basket_complement_description(basket_complement)
      "#{basket_complement.public_name}: #{basket_complement_price_info(entity, basket_complement)}"
    end

    def membership_depot_description(depot)
      baskets = entity.baskets.where(depot: depot)
      "#{Depot.model_name.human}: #{depot.public_name} #{depots_price_info(baskets)}"
    end

    def membership_deliveries_description
      most_used_price =
        entity
          .baskets
          .pluck(:delivery_cycle_price)
          .select(&:positive?)
          .tally
          .max_by { |_, v| v }
          &.first
      if entity.delivery_cycle.price != most_used_price
        cycle = DeliveryCycle.find_by(price: most_used_price)
      end
      cycle ||= entity.delivery_cycle
      [ cycle.invoice_description, delivery_cycle_price_info(entity.baskets) ].join(" ")
    end

    def activity_participations_annual_price_change_description
      i18n_scope = Current.org.activity_i18n_scope
      diff = entity.activity_participations_demanded_diff_from_default
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

    def cur(amount, unit: false, **options)
      super(amount, unit: unit, **options)
    end

    def cur_with_vat_appendice(invoice, amount, unit: false, **options)
      amount = cur(amount).to_s
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
