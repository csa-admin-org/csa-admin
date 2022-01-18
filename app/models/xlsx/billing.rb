module XLSX
  class Billing < Base
    def initialize(year)
      @invoices = Invoice.not_canceled.during_year(year)
      @payments = Payment.during_year(year)
      @memberships = Membership.during_year(year).includes(:member)
      @baskets =
        Basket
          .during_year(year)
          .billable
          .joins(membership: :member)
          .merge(Member.no_salary_basket)
      @memberships_basket_complements =
        MembershipsBasketComplement
          .joins(membership: :member)
          .merge(Membership.during_year(year))
          .merge(Member.no_salary_basket)

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
      add_headers(
        Invoice.human_attribute_name(:description),
        Invoice.human_attribute_name(:unit_price),
        Invoice.human_attribute_name(:total))
      BasketSize.all.each do |basket_size|
        total = @baskets.where(baskets: { basket_size_id: basket_size.id }).sum('baskets.quantity * baskets.basket_price')
        add_line("#{Basket.model_name.human}: #{basket_size.name}", total, basket_size.price)
      end
      if Current.acp.feature_flag?(:basket_price_extra)
        total = @baskets.sum('baskets.quantity * memberships.basket_price_extra')
        add_line("#{Membership.human_attribute_name(:basket_price_extra)}:", total)
      end
      add_empty_line

      if BasketComplement.any?
        BasketComplement.all.each do |basket_complement|
          total =
            if basket_complement.annual_price_type?
              @memberships_basket_complements
                .where(memberships_basket_complements: { basket_complement: basket_complement })
                .sum('memberships_basket_complements.quantity * memberships_basket_complements.price')
            else
              @baskets
                .joins(:baskets_basket_complements)
                .where(baskets_basket_complements: { basket_complement: basket_complement })
                .sum('baskets_basket_complements.quantity * baskets_basket_complements.price')
            end
          add_line("#{BasketComplement.model_name.human}: #{basket_complement.name}", total, basket_complement.price)
        end
        add_empty_line
      end

      if Depot.paid.any?
        Depot.paid.each do |depot|
          total = @baskets.where(baskets: { depot_id: depot.id }).sum('baskets.quantity * baskets.depot_price')
          add_line("#{Depot.model_name.human}: #{depot.name}", total, depot.price)
        end
        add_empty_line
      end

      add_line("#{t('adjustments')}: #{Basket.model_name.human(count: 2)}", @memberships.sum(:baskets_annual_price_change))
      if BasketComplement.any?
        add_line("#{t('adjustments')}: #{BasketComplement.model_name.human}", @memberships.sum(:basket_complements_annual_price_change))
      end
      add_line("#{t('adjustments')}: #{ApplicationController.helpers.activities_human_name}", @memberships.sum(:activity_participations_annual_price_change))

      add_empty_line
      add_line((t('memberships_total')), @memberships.sum(:price))

      add_empty_line
      add_empty_line

      t_invoice = Invoice.model_name.human(count: 2)
      add_line("#{t_invoice}: #{Membership.model_name.human(count: 2)}", @invoices.sum(:memberships_amount))
      if Current.acp.annual_fee
        add_line("#{t_invoice}: #{t('annual_fees')}", invoices_total(:annual_fee), Current.acp.annual_fee)
      end
      if Current.acp.share?
        add_line("#{t_invoice}: #{t('acp_shares')}", @invoices.acp_share.sum(:amount), Current.acp.share_price)
      end
      if Current.acp.feature?('group_buying')
        add_line("#{t_invoice}: #{::GroupBuying::Order.model_name.human(count: 2)}", @invoices.group_buying_order_type.sum(:amount))
      end
      if Current.acp.feature_flag?('shop')
        add_line("#{t_invoice}: #{I18n.t('shop.title')}", @invoices.shop_order_type.sum(:amount))
      end
      if Current.acp.feature?('activity')
        add_line("#{t_invoice}: #{ApplicationController.helpers.activities_human_name}", @invoices.activity_participation_type.sum(:amount))
      end
      add_line("#{t_invoice}: #{t('other')}", @invoices.other_type.sum(:amount))
      add_line(t_invoice, invoices_total(:amount))

      if Current.acp.vat_membership_rate?
        add_empty_line
        add_empty_line

        add_line(t('memberships_net_amount'), invoices_total(:memberships_net_amount))
        add_line(t('memberships_vat_amount'), invoices_total(:memberships_vat_amount))
        add_line(t('memberships_gross_amount'), invoices_total(:memberships_gross_amount))
      end

      add_empty_line
      add_empty_line

      t_payment = Payment.model_name.human(count: 2)
      add_line("#{t_payment}: #{t('isr')}", @payments.isr.sum(:amount))
      add_line("#{t_payment}: #{t('manual')}", @payments.manual.where('amount > 0').sum(:amount))
      add_line("#{t_payment}: #{t('refund')}", @payments.refund.sum(:amount))
      add_line(t_payment, @payments.sum(:amount))

      worksheet.change_column_width(0, 35)
      worksheet.change_column_width(1, 12)
      worksheet.change_column_width(2, 12)
      worksheet.change_column_horizontal_alignment(1, 'right')
      worksheet.change_column_horizontal_alignment(2, 'right')
    end

    def add_line(description, total, price = nil)
      @worksheet.add_cell(@line, 0, description)
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
