# frozen_string_literal: true

module PDF
  class Invoice < Base
    include MembershipsHelper
    include NumbersHelper

    Row = Data.define(:description, :amount, :kind, :italic, :bold, :rule_top, :gap_before, :gap_after)

    attr_reader :invoice, :entity

    def initialize(invoice)
      @invoice = invoice
      @entity = invoice.entity
      # Reload invoice to be sure that the balance is up-to-date
      @missing_amount = ::Invoice.find(invoice.id).missing_amount
    end

    def filename
      invoice.pdf_filename
    end

    private

    def template_path
      "pdfs/invoices/show"
    end

    def stylesheets
      [ "pdf/invoice" ]
    end

    def title
      "#{invoice.document_name} #{invoice.id}"
    end

    def view_assigns
      mode = payment_mode
      {
        invoice: invoice,
        entity: entity,
        pages: build_pages,
        header_meta: build_header_meta,
        member_address: build_member_address,
        amount_header: "#{::Invoice.human_attribute_name(:amount)} (#{currency_symbol(invoice.currency_code)})",
        extra_credit: build_extra_credit,
        footnotes: build_footnotes,
        footer_logos: invoice_footer_logo_data_uris,
        footer_text: Current.org.invoice_footer,
        org_logo_uri: org_logo_data_uri(size: 110),
        payment_mode: mode,
        payment: build_payment_data(mode)
      }
    end

    def build_pages
      all_items = invoice.items.to_a
      max_per_page = 39
      max_last_page = Current.org.swiss_qr? ? 9 : 14
      item_pages =
        if invoice.shop_order_group_type?
          paginate_group(all_items, max_per_page, max_last_page)
        else
          paginate(all_items, max_per_page, max_last_page)
        end

      total_pages = item_pages.size
      item_pages.each_with_index.map do |page_items, index|
        page_number = index + 1
        last_page = page_number == total_pages
        {
          page_number: page_number,
          total_pages: total_pages,
          last_page: last_page,
          rows: build_rows(page_items, all_items: all_items, last_page: last_page)
        }
      end
    end

    def paginate(items, max_per_page, max_last_page)
      pages = []
      remaining = items.dup

      while remaining.size > max_last_page
        page_size = [
          max_per_page,
          [ remaining.size - max_last_page, max_last_page ].max
        ].min
        pages << remaining.shift(page_size)
      end

      pages << remaining
      pages
    end

    def paginate_group(items, max_per_page, max_last_page)
      weights = group_display_weights(items)
      pages = []
      remaining = items.dup
      remaining_weights = weights.dup

      while remaining_weights.sum > max_last_page
        budget = [
          max_per_page,
          [ remaining_weights.sum - max_last_page, max_last_page ].max
        ].min
        count = display_item_count(remaining_weights, budget)
        pages << remaining.shift(count)
        remaining_weights.shift(count)
      end

      pages << remaining
      pages
    end

    def group_display_weights(items)
      items.each_index.map { |index| group_display_weight(items, index) }
    end

    def group_display_weight(items, index)
      following = items[index + 1]
      following.nil? || following.shop_order_section? ? 2 : 1
    end

    def display_item_count(weights, budget)
      rows = 0
      weights.each_with_index do |weight, index|
        next_rows = rows + weight
        return index if next_rows > budget && index.positive?
        return 1 if next_rows > budget

        rows = next_rows
      end
      weights.size
    end

    def build_header_meta
      meta = {
        title: "#{t("numbered", label: invoice.document_name)}\u00A0#{invoice.id}",
        date: I18n.l(invoice.date),
        period: nil,
        shop_order_title: nil,
        shop_order_delivery: nil,
        shop_order_group_period: nil
      }

      case invoice.entity_type
      when "Membership"
        if entity&.date_range
          meta[:period] = display_period(entity.date_range, format: :number)
        end
      when "Shop::Order"
        if entity
          meta[:shop_order_title] = "#{t("numbered", label: ::Shop::Order.model_name.human)}\u00A0#{entity.id}"
          if entity.delivery&.date
            meta[:shop_order_delivery] = "#{::Delivery.model_name.human}: #{I18n.l(entity.delivery.date)}"
          end
        end
      when "Shop::OrderGroup"
        meta[:shop_order_group_period] = entity.display_period if entity
      end

      meta
    end

    def build_member_address
      member = invoice.member
      debtor_name = invoice.sepa? ? invoice.sepa_debtor_name : member.billing_info(:name)
      shares_info =
        if invoice.share_type? && member.shares_info?
          "#{Member.human_attribute_name(:shares_info)}: #{member.shares_info}"
        end

      {
        lines: [
          debtor_name.to_s.truncate(70),
          member.billing_info(:street).to_s.truncate(70),
          "#{member.billing_info(:zip)} #{member.billing_info(:city)}"
        ],
        member_id_line: t(".member_id", id: member.id),
        shares_info_line: shares_info
      }
    end

    def build_rows(page_items, all_items:, last_page:)
      reset_appendice_star
      entries = []

      case invoice.entity_type
      when "Membership"
        build_membership_entries(entries) if entity
      when "ActivityParticipation"
        entries << { description: activity_participation_description, amount: cur(invoice.amount) }
      when "Share"
        str =
          if invoice.shares_number.positive?
            t("shares_number", count: invoice.shares_number)
          else
            t("shares_number_negative", count: invoice.shares_number.abs)
          end
        entries << { description: str, amount: cur(invoice.amount) }
      when "Other", "Shop::Order", "NewMemberFee"
        page_items.each do |item|
          entries << { description: item.description, amount: cur(item.amount) }
        end
      when "Shop::OrderGroup"
        build_shop_order_group_entries(page_items, all_items, entries)
      end

      if last_page
        build_summary_entries(entries)
        apply_last_page_entry_styles(entries)
      end

      finalize_rows(entries, last_page: last_page)
    end

    def build_membership_entries(entries)
      if Current.org.invoice_membership_summary_only?
        entries << {
          description: t("membership_summary"),
          amount: cur_with_vat_appendice(invoice, entity.price)
        }
        return
      end

      if entity.basket_sizes_price.positive?
        entity.basket_sizes.uniq.each do |basket_size|
          entries << {
            description: membership_basket_size_description(basket_size),
            amount: cur(entity.basket_size_total_price(basket_size))
          }
        end
      end
      unless entity.baskets_annual_price_change.zero?
        entries << {
          description: t("baskets_annual_price_change"),
          amount: cur(entity.baskets_annual_price_change)
        }
      end
      if entity.basket_complements_price.positive?
        basket_complements = (
          entity.basket_complements + entity.subscribed_basket_complements
        ).uniq
        basket_complements.each do |basket_complement|
          entries << {
            description: membership_basket_complement_description(basket_complement),
            amount: cur(entity.basket_complement_total_price(basket_complement))
          }
        end
      end
      unless entity.basket_complements_annual_price_change.zero?
        entries << {
          description: t("basket_complements_annual_price_change"),
          amount: cur(entity.basket_complements_annual_price_change)
        }
      end
      if entity.baskets_price_extra.nonzero?
        entries << {
          description: membership_baskets_price_extra_description,
          amount: cur(entity.baskets_price_extra)
        }
      end
      entity.depots.uniq.each do |depot|
        price = entity.depot_total_price(depot)
        if price.positive?
          entries << {
            description: membership_depot_description(depot),
            amount: cur(price)
          }
        end
      end
      if entity.deliveries_price.positive?
        entries << {
          description: membership_deliveries_description,
          amount: cur(entity.deliveries_price)
        }
      end
      unless entity.activity_participations_annual_price_change.zero?
        entries << {
          description: activity_participations_annual_price_change_description,
          amount: cur(entity.activity_participations_annual_price_change)
        }
      end
      if entity.price_reduction_amount.nonzero?
        entries << {
          description: entity.price_reduction.public_name,
          amount: cur(-entity.price_reduction_amount)
        }
      end
      if (redemption = entity.promotion_claim)&.billable? && redemption.benefit_amount&.nonzero?
        entries << {
          description: redemption.public_name,
          amount: cur(-redemption.benefit_amount)
        }
      end
    end

    def activity_participation_description
      if entity
        str = t("missed_activity_participation_with_date", date: I18n.l(entity.activity.date))
        if invoice.missing_activity_participations_count > 1
          str += " (#{invoice.missing_activity_participations_count} #{ActivityParticipation.human_attribute_name(:participants).downcase})"
        end
        str
      elsif invoice.missing_activity_participations_count == 1
        t("missed_activity_participation",
          year: invoice.missing_activity_participations_fiscal_year)
      else
        t("missed_activity_participations",
          year: invoice.missing_activity_participations_fiscal_year,
          count: invoice.missing_activity_participations_count)
      end
    end

    def build_shop_order_group_entries(page_items, all_items, entries)
      page_items.each do |item|
        if item.shop_order_section?
          entries << { description: item.description, amount: "", kind: :section }
        else
          entries << { description: item.description, amount: cur(item.amount) }
        end

        next unless shop_order_section_closed?(all_items, item)

        amount = shop_order_section_amount(all_items, item)
        next if amount.nil?

        entries << { description: t("subtotal"), amount: cur(amount), kind: :subtotal }
      end
    end

    def build_summary_entries(entries)
      if invoice.paid_memberships_amount.to_f.positive?
        entries << {
          description: t("paid_memberships_amount"),
          amount: cur(-invoice.paid_memberships_amount),
          italic: true
        }
        entries << {
          description: t("remaining_annual_memberships_amount"),
          amount: cur(invoice.remaining_memberships_amount),
          annual_membership_total: true
        }
      elsif invoice.remaining_memberships_amount?
        entries << {
          description: t("annual_memberships_amount"),
          amount: cur(invoice.remaining_memberships_amount),
          annual_membership_total: true
        }
      end

      if invoice.memberships_amount?
        entries << {
          description: invoice.memberships_amount_description,
          amount: cur_with_vat_appendice(invoice, invoice.memberships_amount)
        }
      end

      if invoice.annual_fee?
        entries << {
          description: t("annual_fee"),
          amount: cur(invoice.annual_fee)
        }
      end

      if invoice.amount_percentage?
        entries << {
          description: t("total_before_percentage"),
          amount: cur(invoice.amount_before_percentage),
          rule_top: true,
          gap_before: true
        }
        entries << {
          description: _number_to_percentage(invoice.amount_percentage, precision: 1),
          amount: cur(invoice.amount - invoice.amount_before_percentage)
        }
      end

      if invoice.amount.positive? && @missing_amount != invoice.amount
        already_paid = invoice.amount - @missing_amount
        credit_amount = cur(-(already_paid + invoice.member.credit_amount))
        unless invoice.memberships_amount?
          entries << {
            description: t("total"),
            amount: cur_with_vat_appendice(invoice, invoice.amount),
            rule_top: invoice.entity_type != "Membership",
            gap_before: invoice.entity_type != "Membership"
          }
        end
        entries << {
          description: t("credit_amount"),
          amount: "#{appendice_star} #{credit_amount}",
          italic: true
        }
        entries << {
          description: t("missing_amount"),
          amount: cur(@missing_amount)
        }
      elsif invoice.memberships_amount? && invoice.annual_fee?
        entries << {
          description: t("total"),
          amount: cur(invoice.amount)
        }
      elsif invoice.entity_type != "Membership"
        entries << {
          description: t("total"),
          amount: cur_with_vat_appendice(invoice, invoice.amount)
        }
      end
    end

    def apply_last_page_entry_styles(entries)
      return if entries.empty?

      entries.each do |entry|
        next if entry[:kind] == :section

        entry[:italic] = true if entry[:amount].to_s.empty?
      end

      last_entry = entries.last
      last_entry[:bold] = true
      if (@missing_amount != invoice.amount) ||
          (invoice.memberships_amount? && (invoice.annual_fee? || !invoice.memberships_amount_description?)) ||
          invoice.entity_type != "Membership"
        last_entry[:rule_top] = true
        last_entry[:gap_before] = true
      end

      if invoice.memberships_amount_description?
        annual_entry = entries.reverse.find { |e| e[:annual_membership_total] }
        if annual_entry
          annual_entry[:rule_top] = true
          annual_entry[:gap_before] = true
          annual_entry[:gap_after] = true
        end
      end
    end

    def finalize_rows(entries, last_page:)
      last_subtotal_index = last_page ? entries.rindex { |e| e[:kind] == :subtotal } : nil

      entries.each_with_index.map do |entry, index|
        kind = entry[:kind] || :item
        gap_after = entry[:gap_after] == true || (index == last_subtotal_index)
        Row.new(
          description: entry[:description].to_s,
          amount: entry[:amount].to_s,
          kind: kind,
          italic: entry[:italic] == true,
          bold: entry[:bold] == true,
          rule_top: entry[:rule_top] == true,
          gap_before: entry[:gap_before] == true,
          gap_after: gap_after)
      end
    end

    def build_extra_credit
      return unless invoice.member.credit_amount.positive?

      {
        label: t("extra_credit"),
        amount: cur(invoice.member.credit_amount)
      }
    end

    def build_footnotes
      reset_appendice_star
      notes = []

      if invoice.vat_amount&.positive?
        vat_line = [
          "#{appendice_star} #{t("all_taxes_included")}",
          "#{cur(invoice.amount_without_vat, unit: true)} #{t("without_taxes")}",
          "#{cur(invoice.vat_amount, unit: true)} #{t("vat")} (#{invoice.vat_rate}%)"
        ].join(", ")
        notes << { lines: [ vat_line, "#{t("numbered", label: t("vat"))} #{Current.org.vat_number}" ], css_class: "invoice-footnote-group invoice-footnote-group--vat" }
      end

      if invoice.amount.positive? && @missing_amount != invoice.amount
        notes << {
          lines: "#{appendice_star} #{t("credit_amount_text")}".split("\n"),
          css_class: "invoice-footnote-group invoice-footnote-group--normal"
        }
      end

      replacing_ids = invoice.previously_canceled_entity_invoice_ids
      if replacing_ids.present?
        replacing_text =
          if replacing_ids.many?
            t("replacing_invoices", ids: replacing_ids.to_sentence)
          else
            t("replacing_invoice", id: replacing_ids.first)
          end
        notes << { lines: [ replacing_text ], css_class: "invoice-footnote-group invoice-footnote-group--wide" }
      end

      info_lines = []
      if invoice.entity_type == "Shop::Order" && entity&.delivery&.date && Current.org.shop_invoice_info.present?
        info_lines << (Current.org.shop_invoice_info % { date: I18n.l(entity.delivery.date) })
      elsif invoice.shop_order_group_type? && Current.org.shop_invoice_info.present? && !Current.org.shop_invoice_info.include?("%{date}")
        info_lines << Current.org.shop_invoice_info
      end

      invoice_info = invoice.sepa? ? Current.org.invoice_sepa_info : Current.org.invoice_info
      info_lines << invoice_info if invoice_info.present?

      if info_lines.any?
        notes << {
          lines: info_lines.flat_map { |line| line.to_s.split("\n") },
          css_class: "invoice-footnote-group invoice-footnote-group--info"
        }
      end
      notes
    end

    def payment_mode
      if local_currency?
        :local_currency_qr
      elsif Current.org.swiss_qr?
        :swiss_qr
      elsif Current.org.sepa_country?
        invoice.sepa_mandate.present? ? :payment_info : :epc_qr
      else
        :payment_info
      end
    end

    def build_payment_data(mode)
      case mode
      when :swiss_qr
        build_swiss_qr_data
      when :epc_qr
        build_epc_qr_data
      when :local_currency_qr
        build_local_currency_qr_data
      else
        build_payment_info_data
      end
    end

    def build_swiss_qr_data
      member = invoice.member
      {
        receipt_title: t("payment.receipt"),
        payment_part_title: t("payment.payment_part"),
        payable_to_account_label: t("payment.payable_to_account"),
        reference_label: t("payment.reference"),
        further_information_label: t("payment.further_information"),
        payable_by_label: t("payment.payable_by"),
        currency_label: t("payment.currency"),
        amount_label: t("payment.amount"),
        acceptance_point_label: t("payment.acceptance_point"),
        iban: Current.org.iban_formatted,
        creditor_lines: [
          Current.org.creditor_name,
          Current.org.creditor_street,
          "#{Current.org.creditor_zip} #{Current.org.creditor_city}"
        ],
        reference: invoice.reference.formatted,
        further_information: "#{invoice.document_name} #{invoice.id}",
        debtor_lines: [
          member.billing_info(:name).to_s.truncate(70),
          member.billing_info(:street).to_s.truncate(70),
          "#{member.billing_info(:zip)} #{member.billing_info(:city)}"
        ],
        currency_code: Current.org.currency_code,
        amount: cur(@missing_amount, delimiter: " "),
        qr_data_uri: swiss_qr_data_uri,
        scissor_data_uri: scissor_data_uri
      }
    end

    def build_epc_qr_data
      {
        title: t("payment.payment_part"),
        qr_data_uri: epc_qr_data_uri,
        caption: t("payment.pay_with_code"),
        iban_label: "IBAN",
        iban: Current.org.iban_formatted,
        payable_to_label: t("payment.payable_to"),
        creditor_name: Current.org.creditor_name,
        reference_label: t("payment.reference_number"),
        reference: invoice.reference.formatted,
        amount_label: t("payment.amount"),
        amount: "#{Current.org.currency_code} #{cur(@missing_amount, delimiter: " ")}"
      }
    end

    def build_local_currency_qr_data
      currency_name = I18n.t("local_currency.#{invoice.currency_code.downcase}.default")
      {
        title: t("payment.payment_part_with_currency", currency: currency_name),
        qr_data_uri: local_currency_qr_data_uri,
        caption: t("payment.scan_to_pay"),
        wallet_label: Organization.human_attribute_name(:local_currency_wallet),
        wallet: Current.org.local_currency_wallet,
        payable_to_label: t("payment.payable_to"),
        creditor_name: Current.org.creditor_name,
        reference_label: t("payment.reference"),
        reference: invoice.reference.formatted,
        amount_label: t("payment.amount"),
        amount: "#{invoice.currency_code} #{cur(@missing_amount, delimiter: " ")}"
      }
    end

    def build_payment_info_data
      member = invoice.member
      sepa = invoice.sepa?
      debtor_name = sepa ? invoice.sepa_debtor_name : member.billing_info(:name)

      {
        title: sepa ? t("payment.sepa_direct_debit") : t("payment.payment_part"),
        sepa: sepa,
        amount_label: t("payment.amount"),
        amount: "#{Current.org.currency_code} #{cur(@missing_amount, delimiter: " ")}",
        payable_to_label: t("payment.payable_to"),
        creditor_lines: [
          Current.org.creditor_name,
          Current.org.creditor_street,
          "#{Current.org.creditor_zip} #{Current.org.creditor_city}"
        ],
        creditor_iban: Current.org.iban_formatted,
        sepa_creditor_id_label: t("payment.sepa_creditor_identifier"),
        sepa_creditor_id: Current.org.sepa_creditor_identifier,
        reference_label: t("payment.reference_number"),
        reference: invoice.reference.formatted,
        payable_by_label: t("payment.payable_by"),
        debtor_lines: [
          debtor_name.to_s.truncate(70),
          member.billing_info(:street).to_s.truncate(70),
          "#{member.billing_info(:zip)} #{member.billing_info(:city)}"
        ],
        debtor_iban: sepa ? invoice.sepa_mandate.iban_formatted : nil,
        sepa_mandate_id_label: t("payment.sepa_mandate_id"),
        sepa_mandate_umr: sepa ? invoice.sepa_mandate.umr : nil,
        sepa_mandate_signed_on: sepa ? I18n.l(invoice.sepa_mandate.signed_on, format: :short) : nil
      }
    end

    def invoice_footer_logos
      logos = Current.org.invoice_logos.to_a
      return logos unless invoice.membership_type?

      reduction = entity&.price_reduction
      return logos unless reduction&.invoice_logo&.attached?

      logos + [ reduction.invoice_logo ]
    end

    def invoice_footer_logo_data_uris
      @invoice_footer_logo_data_uris ||=
        invoice_footer_logos.filter_map do |invoice_logo|
          blob = invoice_logo.variant(resize_to_limit: [ 135, 135 ]).processed
          bytes_data_uri(blob.download, content_type: blob.content_type || "image/png")
        rescue CSAAdmin::UnprocessableUpload => e
          Rails.logger.error "Failed to process logo ID #{invoice_logo.id}: #{e.message}"
          nil
        end
    end

    def swiss_qr_data_uri
      @swiss_qr_data_uri ||= file_data_uri(Billing::SwissQRCode.image(invoice), content_type: "image/png")
    end

    def epc_qr_data_uri
      @epc_qr_data_uri ||= bytes_data_uri(Billing::EPCQRCode.svg(invoice), content_type: "image/svg+xml")
    end

    def local_currency_qr_data_uri
      @local_currency_qr_data_uri ||= file_data_uri(LocalCurrency::Radis.qr_code(invoice), content_type: "image/png")
    end

    def scissor_data_uri
      @scissor_data_uri ||= asset_data_uri(Rails.root.join("lib/assets/images/scissor.png"), content_type: "image/png")
    end

    def file_data_uri(file, content_type:)
      bytes_data_uri(File.binread(file.path), content_type: content_type)
    ensure
      if file.is_a?(Tempfile)
        file.close!
      elsif file.respond_to?(:close)
        file.close
      end
    end

    def shop_order_section_closed?(all_items, item)
      index = all_items.index(item)
      return false unless index

      following = all_items[index + 1]
      following.nil? || following.shop_order_section?
    end

    def shop_order_section_amount(all_items, item)
      index = all_items.index(item)
      header = all_items[0..index].rindex(&:shop_order_section?)
      return unless header

      all_items[(header + 1)..index].sum(&:amount)
    end

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
      "#{depot.invoice_description} #{depots_price_info(baskets)}"
    end

    def membership_deliveries_description
      most_used_price =
        entity
          .baskets
          .billable
          .where("baskets.quantity > 0")
          .group(:delivery_cycle_price)
          .sum("baskets.quantity")
          .max_by { |_, quantity| quantity }
          &.first
      if entity.delivery_cycle.price != most_used_price
        cycle = DeliveryCycle.find_by(price: most_used_price)
      end
      cycle ||= entity.delivery_cycle
      [ cycle.invoice_description, delivery_cycle_price_info(entity.baskets) ].join(" ")
    end

    def activity_participations_annual_price_change_description
      diff = entity.activity_participations_demanded_diff_from_default
      if diff.positive?
        Membership.human_attribute_name("activity_participations_annual_price_change_reduction", count: diff)
      elsif diff.negative?
        Membership.human_attribute_name("activity_participations_annual_price_change_negative", count: diff)
      elsif entity.activity_participations_annual_price_change.positive?
        Membership.human_attribute_name("activity_participations_annual_price_change_positive")
      else
        Membership.human_attribute_name("activity_participations_annual_price_change_default")
      end
    end

    def local_currency?
      Current.org.feature?("local_currency") &&
        invoice.currency_code == Current.org.local_currency_code
    end

    def cur(amount, unit: false, **options)
      super(amount, unit: unit, currency_code: invoice.currency_code, **options)
    end

    def cur_with_vat_appendice(invoice, amount)
      formatted = cur(amount).to_s
      if invoice.vat_amount&.positive?
        "#{appendice_star} #{formatted}"
      else
        formatted
      end
    end

    def t(key, **args)
      I18n.t("invoices.pdf.#{key}", **args)
    end
  end
end
