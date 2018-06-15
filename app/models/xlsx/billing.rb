module XLSX
  class Billing < Base
    def initialize(year)
      @invoices = Invoice.not_canceled.during_year(year)
      @memberships = Membership.during_year(year)

      build_worksheet(t('title'))
    end

    def filename
      [
        Current.acp.name.parameterize,
        t('title').parameterize,
        Time.current.strftime('%Y%m%d-%Hh%M')
      ].join('-') + '.xlsx'
    end

    private

    def build_worksheet(name)
      worksheet = add_worksheet(name)
      add_header(
        Invoice.human_attribute_name(:descritption),
        Invoice.human_attribute_name(:unit_price),
        Invoice.human_attribute_name(:total))
      BasketSize.all.each do |basket_size|
        total = @memberships.sum { |m| m.basket_size_total_price(basket_size.id) }
        add_line("#{Basket.model_name.human}: #{basket_size.name}", total, basket_size.price)
      end
      add_empty_line

      if BasketComplement.any?
        BasketComplement.all.each do |basket_complement|
          total = @memberships.sum { |m| m.basket_complement_total_price(basket_complement.id) }
          add_line("#{BasketComplement.model_name.human}: #{basket_complement.name}", total, basket_complement.price)
        end
        add_empty_line
      end

      Distribution.paid.each do |distribution|
        total = @memberships.sum { |m| m.distribution_total_price(distribution.id) }
        add_line("#{Distribution.model_name.human}: #{distribution.name}", total, distribution.price)
      end
      add_empty_line

      add_line("#{t('adjustments')}: #{ApplicationController.helpers.halfdays_human_name}", @memberships.sum(&:halfday_works_annual_price))

      if Current.acp.annual_fee
        add_line(t('annual_fees'), invoices_total(:annual_fee), Current.acp.annual_fee)
      end
      if Current.acp.share_price
        add_line(t('acp_shares'), @invoices.acp_share.sum(:amount), Current.acp.share_price)
      end

      add_empty_line
      add_empty_line

      if Current.acp.vat_membership_rate?
        add_line(t('memberships_net_amount'), invoices_total(:memberships_net_amount))
        add_line(t('memberships_vat_amount'), invoices_total(:memberships_vat_amount))
        add_line(t('memberships_gross_amount'), invoices_total(:memberships_gross_amount))

        add_empty_line
        add_empty_line
      end

      add_line(t('amount'), invoices_total(:amount))
      add_line(t('balance_without_overbalance'), invoices_total(:balance_without_overbalance))
      add_line(t('missing_amount'), invoices_total(:missing_amount))
      add_line(t('overbalance'), invoices_total(:overbalance))

      worksheet.change_column_width(0, 35)
      worksheet.change_column_width(1, 12)
      worksheet.change_column_width(2, 12)
      worksheet.change_column_horizontal_alignment(1, 'right')
      worksheet.change_column_horizontal_alignment(2, 'right')
    end

    def add_line(descritption, total, price = nil)
      @worksheet.add_cell(@line, 0, descritption)
      @worksheet.add_cell(@line, 1, price).set_number_format('0.000')
      @worksheet.add_cell(@line, 2, total).set_number_format('0.00')
      @line += 1
    end

    def invoices_total(method)
      @invoices.sum { |i| i.send(method) || 0 }
    end

    def t(key, *args)
      I18n.t("billing.#{key}", *args)
    end
  end
end
