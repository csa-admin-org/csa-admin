module XLSX
  class Billing < Base
    def initialize(year)
      @invoices = Invoice.not_canceled.during_year(year)
      @memberships = Membership.during_year(year)

      build_worksheet('Facturation')
    end

    def filename
      [
        Current.acp.name.parameterize,
        'facturation',
        Time.current.strftime('%Y%m%d-%Hh%M')
      ].join('-') + '.xlsx'
    end

    private

    def build_worksheet(name)
      worksheet = add_worksheet(name)
      add_header('Description', 'Prix unité', 'Total')

      BasketSize.all.each do |basket_size|
        total = @memberships.sum { |m| m.basket_size_total_price(basket_size.id) }
        add_line("Panier #{basket_size.name}", total, basket_size.price)
      end
      add_empty_line

      if BasketComplement.any?
        BasketComplement.all.each do |basket_complement|
          total = @memberships.sum { |m| m.basket_complement_total_price(basket_complement.id) }
          add_line("Complément #{basket_complement.name}", total, basket_complement.price)
        end
        add_empty_line
      end

      Distribution.paid.each do |distribution|
        total = @memberships.sum { |m| m.distribution_total_price(distribution.id) }
        add_line("Distribution #{distribution.name}", total, distribution.price)
      end
      add_empty_line

      add_line("Ajustement #{ApplicationController.helpers.halfdays_human_name}", @memberships.sum(&:halfday_works_annual_price))
      add_line('Cotisations', invoices_total(:support_amount), Current.acp.support_price)

      add_empty_line
      add_empty_line

      add_line('Facturé', invoices_total(:amount))
      add_line('Payé', invoices_total(:balance_without_overbalance))
      add_line('Non-payé (manquant)', invoices_total(:missing_amount))
      add_line('Payé en trop (pour année suivante)', invoices_total(:overbalance))

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
  end
end
