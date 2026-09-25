# frozen_string_literal: true

module Shop::Order::GroupInvoice
  extend ActiveSupport::Concern

  included do
    scope :without_invoice_period, -> {
      if Current.org.shop_invoice_period?
        none
      else
        joins(:member).where(members: { shop_invoice_period: nil })
      end
    }
    scope :with_invoice_period, -> {
      if Current.org.shop_invoice_period?
        all
      else
        joins(:member).where.not(members: { shop_invoice_period: nil })
      end
    }
  end

  def group_invoice?
    member.effective_shop_invoice_period.present?
  end

  def group_invoice_status_name
    if group_invoice? && pending? && delivery_date&.past?
      I18n.t("shop.group_invoice.to_invoice")
    else
      state_i18n_name
    end
  end

  def invoice_period_key
    return unless group_invoice? && delivery_date

    Shop::InvoicePeriod.key_for(member.effective_shop_invoice_period, delivery_date)
  end

  def group_billing_on
    return unless group_invoice? && delivery_date

    Shop::InvoicePeriod.billing_on(member.effective_shop_invoice_period, delivery_date)
  end

  def group_invoice_due?(on: Date.current)
    Shop::InvoicePeriod.due?(member.effective_shop_invoice_period, delivery_date, on: on)
  end

  def group_invoice_overdue?(on: Date.current)
    billing_on = group_billing_on
    billing_on.present? && billing_on < on
  end

  def invoice_section_description
    label = I18n.t("invoices.pdf.numbered", label: self.class.model_name.human)
    "#{label}\u00A0#{id}, #{I18n.l(delivery_date, format: :medium)}"
  end

  def invoice_percentage_description
    _number_to_percentage(amount_percentage, precision: 1)
  end

  def invoice_percentage_delta
    return 0 unless amount_percentage?

    base = items.sum(&:amount)
    (base * (1 + amount_percentage / 100.0)).round_to_one_cent - base
  end
end
