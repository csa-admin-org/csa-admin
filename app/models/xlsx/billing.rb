# frozen_string_literal: true

module XLSX
  class Billing < Base
    def initialize(year)
      @year = year
      @invoices = Invoice.not_canceled.during_year(year)
      @payments = Payment.during_year(year)
      @memberships = Membership.during_year(year).includes(:member)
      @baskets =
        Basket
          .during_year(year)
          .billable
          .joins(membership: :member)
          .merge(Member.no_salary_basket)
      @basket_sizes = BasketSize.where(id: @baskets.pluck(:basket_size_id)).ordered
      @memberships_basket_complements =
        MembershipsBasketComplement
          .joins(membership: :member)
          .merge(Membership.during_year(year))
          .merge(Member.no_salary_basket)

      main_worksheet
      shop_worksheet if Current.org.feature?("shop")
    end

    def filename
      [
        Current.org.name.parameterize,
        t("title").parameterize,
        Time.current.strftime("%Y%m%d-%Hh%M")
      ].join("-") + ".xlsx"
    end

    private

    def main_worksheet
      worksheet = add_worksheet(t("title"))
      add_headers(
        Invoice.human_attribute_name(:description),
        Invoice.human_attribute_name(:unit_price),
        Invoice.human_attribute_name(:total))
      @basket_sizes.each do |basket_size|
        total = @baskets.where(baskets: { basket_size_id: basket_size.id }).sum("baskets.quantity * baskets.basket_price")
        add_line("#{Basket.model_name.human}: #{basket_size.name}", total, basket_size.price)
      end
      if Current.org.feature?("basket_price_extra")
        total = @baskets.sum("baskets.quantity * baskets.calculated_price_extra")
        add_line(Current.org.basket_price_extra_title, total)
      end
      add_empty_line

      basket_complements = BasketComplement.for(@baskets)
      if basket_complements.any?
        basket_complements.each do |basket_complement|
          total =
            @baskets
              .joins(:baskets_basket_complements)
              .where(baskets_basket_complements: { basket_complement: basket_complement })
              .sum("baskets_basket_complements.quantity * baskets_basket_complements.price")
          add_line("#{BasketComplement.model_name.human}: #{basket_complement.name}", total, basket_complement.price)
        end
        add_empty_line
      end

      if Depot.paid.any?
        Depot.paid.each do |depot|
          total = @baskets.where(baskets: { depot_id: depot.id }).sum("baskets.quantity * baskets.depot_price")
          add_line("#{Depot.model_name.human}: #{depot.name}", total, depot.price)
        end
        add_empty_line
      end

      add_line("#{t('adjustments')}: #{Basket.model_name.human(count: 2)}", @memberships.sum(:baskets_annual_price_change))
      if basket_complements.any?
        add_line("#{t('adjustments')}: #{BasketComplement.model_name.human}", @memberships.sum(:basket_complements_annual_price_change))
      end
      add_line("#{t('adjustments')}: #{ApplicationController.helpers.activities_human_name}", @memberships.sum(:activity_participations_annual_price_change))

      add_empty_line
      add_line((t("memberships_total")), @memberships.sum(:price))

      add_empty_line
      add_empty_line

      t_invoice = Invoice.model_name.human(count: 2)
      invoices_per_year = @invoices.membership.includes(:entity).all.group_by(&:entity_fy_year).sort
      invoices_per_year.each do |year, invoices|
        add_line(t_invoice_with_year(Membership.model_name.human(count: 2), year), invoices.sum(&:memberships_amount))
      end
      if Current.org.annual_fee?
        # Add current year if not present (no memberships)
        unless invoices_per_year.map(&:first).include?(@year)
          invoices_per_year.unshift([ @year, [] ])
        end
        invoices_per_year.each do |year, invoices|
          amount = invoices.sum { |i| i.annual_fee || 0 }
          if year == @year # Add annual fee invoices outside of memberships
            amount += @invoices.where(entity_type: "AnnualFee").sum(:amount)
          end
          add_line(t_invoice_with_year(t("annual_fees"), year), amount, Current.org.annual_fee)
        end
      end
      if Current.org.share?
        add_line("#{t_invoice}: #{t('shares')}", @invoices.share.sum(:amount), Current.org.share_price)
      end
      if Current.org.feature?("shop")
        add_line("#{t_invoice}: #{I18n.t('shop.title_orders', count: 2)}", @invoices.shop_order_type.sum(:amount))
      end
      if Current.org.feature?("activity")
        @invoices.activity_participation_type.group(:missing_activity_participations_fiscal_year).sum(:amount).sort.each do |year, amount|
          add_line(t_invoice_with_year(ApplicationController.helpers.activities_human_name, year), amount)
        end
      end
      if Current.org.feature?("new_member_fee")
        add_line("#{t_invoice}: #{I18n.t('invoices.entity_type.new_member_fee')}", @invoices.new_member_fee_type.sum(:amount))
      end
      add_line("#{t_invoice}: #{t('other')}", @invoices.other_type.sum(:amount))
      add_line(t_invoice, invoices_total(:amount))

      if Current.org.vat_number?
        add_empty_line
        add_empty_line

        add_line(t("amount_without_vat"), invoices_total(:amount_without_vat))
        add_line(t("vat_amount"), invoices_total(:vat_amount))
        add_line(t("amount_with_vat"), invoices_total(:amount_with_vat))
      end

      add_empty_line
      add_empty_line

      t_payment = Payment.model_name.human(count: 2)
      add_line("#{t_payment}: #{t('import')}", @payments.import.sum(:amount))
      add_line("#{t_payment}: #{t('manual')}", @payments.manual.where("amount > 0").sum(:amount))
      add_line("#{t_payment}: #{t('refund')}", @payments.refund.sum(:amount))
      add_line(t_payment, @payments.not_ignored.sum(:amount))

      worksheet.change_column_width(0, 35)
      worksheet.change_column_width(1, 12)
      worksheet.change_column_width(2, 12)
      worksheet.change_column_horizontal_alignment(1, "right")
      worksheet.change_column_horizontal_alignment(2, "right")
    end

    def add_line(description, total, price = nil)
      @worksheet.add_cell(@line, 0, description)
      @worksheet.add_cell(@line, 1, price).set_number_format("0.000")
      @worksheet.add_cell(@line, 2, total).set_number_format("0.00")
      @line += 1
    end

    def shop_worksheet
      worksheet = add_worksheet(I18n.t("shop.title"))

      add_headers(
        ::Shop::Product.model_name.human(count: 1),
        ::Shop::ProductVariant.model_name.human(count: 1),
        ::Shop::Producer.model_name.human(count: 1),
        ::Shop::Tag.model_name.human(count: 2),
        ::Shop::OrderItem.human_attribute_name(:quantity),
        Invoice.human_attribute_name(:total))

      orders = ::Shop::Order.invoiced.during_year(@year).includes(items: [ :product_variant, product: :producer ])
      variants = {}
      orders.find_each do |order|
        order.items.each do |item|
          variants[item.product_variant] ||= { quantity: 0, amount: 0 }
          variants[item.product_variant][:quantity] += item.quantity
          variants[item.product_variant][:amount] += item.amount_after_percentage
        end
      end
      variants.sort_by { |variant, _| variant.product.name }.each do |variant, data|
        add_product_line(variant, data[:quantity], data[:amount])
      end

      worksheet.change_column_width(0, 35)
      worksheet.change_column_width(1, 20)
      worksheet.change_column_width(2, 35)
      worksheet.change_column_width(3, 15)
      worksheet.change_column_horizontal_alignment(4, "right")
      worksheet.change_column_horizontal_alignment(5, "right")
    end

    def add_product_line(variant, quantity, total)
      @worksheet.add_cell(@line, 0, variant.product.name)
      @worksheet.add_cell(@line, 1, variant.name)
      @worksheet.add_cell(@line, 2, variant.product.producer.name)
      @worksheet.add_cell(@line, 3, variant.product.tags.map(&:name).join(", "))
      @worksheet.add_cell(@line, 4, quantity).set_number_format("0")
      @worksheet.add_cell(@line, 5, total).set_number_format("0.00")
      @line += 1
    end

    def invoices_total(method)
      @invoices.sum { |i| i.send(method) || 0 }
    end

    def t(key, *args)
      I18n.t("billing.#{key}", *args)
    end

    def t_invoice_with_year(text, year)
      txt = "#{Invoice.model_name.human(count: 2)}: #{text}"
      if year != @year
        fy = Current.org.fiscal_year_for(year)
        txt += " (#{fy})"
      end
      txt
    end
  end
end
