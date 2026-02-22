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

  def recurring_billing_row_content(arbre, next_date:, path:, authorized:)
    if Current.org.recurring_billing?
      if next_date
        arbre.div class: "flex items-center justify-end gap-2" do
          arbre.span { l(next_date, format: :medium) }
          if authorized
            arbre.div do
              panel_button t("active_admin.resource.show.recurring_billing"), path,
                disabled: !Current.org.iban?,
                disabled_tooltip: t("active_admin.resource.show.recurring_billing_iban_missing", iban_type: Current.org.iban_type_name),
                form: { class: "inline" },
                data: { confirm: t("active_admin.resource.show.recurring_billing_confirm") }
            end
          end
        end
      end
    else
      arbre.span class: "italic text-gray-400 dark:text-gray-600" do
        t("active_admin.resource.show.recurring_billing_disabled")
      end
    end
  end
end
