# frozen_string_literal: true

module ActiveAdmin::BillingHelper
  def previsional_details(arbre, total_amount, amounts_by_month, unit: true)
    if amounts_by_month.present?
      arbre.details do
        arbre.summary { cur(total_amount, unit: unit) }
        arbre.div class: "details-grid" do
          amounts_by_month.each do |month_key, amount|
            arbre.span(class: "details-month") { Billing::PrevisionalInvoicing.month_label(month_key) }
            arbre.span(class: "details-amount") { cur(amount, unit: false) }
          end
        end
      end
    else
      cur(total_amount, unit: unit)
    end
  end
end
