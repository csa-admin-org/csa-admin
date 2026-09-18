# frozen_string_literal: true

module InvoicesHelper
  def entity_type_collection
    Invoice.used_entity_types.map { |type|
      [ t_invoice_entity_type(type), type ]
    }.sort_by { |a| a.first }
  end

  def membership_invoice_cancel_confirm(invoice)
    if invoice.membership_type? && invoice.entity&.current_or_future_year?
      t("active_admin.shared.action_items.cancel_membership_invoice_confirm")
    else
      t("active_admin.shared.action_items.cancel_invoice_confirm")
    end
  end

  def membership_invoice_callout_html(invoice)
    if invoice.entity.current_or_future_year?
      membership_url =
        if authorized?(:update, invoice.entity)
          edit_membership_path(invoice.entity)
        else
          membership_path(invoice.entity)
        end
      t("active_admin.resource.show.membership_invoice_callout_html",
        membership_url: membership_url)
    else
      t("active_admin.resource.show.membership_invoice_past_fy_callout_html",
        other_invoice_url: new_invoice_path(member_id: invoice.member_id, entity_type: "Other"))
    end
  end

  def membership_invoice_callout_handbook_link(invoice)
    if invoice.entity.current_or_future_year?
      handbook_icon_link("billing", anchor: "billing-cookbook")
    else
      handbook_icon_link("billing", anchor: "manual-invoice")
    end
  end

  def display_entity(invoice, link: true)
    if link && invoice.entity
      auto_link invoice.entity
    elsif invoice.entity.is_a?(Membership)
      if invoice.annual_fee?
        t("invoices.entity_type.membership_with_annual_fee", fiscal_year: invoice.entity.fiscal_year)
      else
        t("invoices.entity_type.membership", fiscal_year: invoice.entity.fiscal_year)
      end
    elsif invoice.entity_type == "Shop::Order"
      t("shop.title")
    else
      t_invoice_entity_type(invoice.entity_type)
    end
  end

  def t_invoice_entity_type(type)
    case type
    when "ActivityParticipation" then activity_human_name
    when "Shop::Order" then I18n.t("shop.title_orders", count: 1)
    else
      type.constantize.model_name.human
    end
  rescue NameError
    I18n.t("invoices.entity_type.#{type.underscore}")
  end

  def link_to_invoice_pdf(invoice, title: "PDF", **options, &block)
    return unless invoice
    return if invoice.processing?
    return unless invoice.pdf_current?

    link_to pdf_invoice_path(invoice), **options, title: title, target: "_blank", class: "invoice-pdf-link" do
      if block
        block.call
      else
        icon("file-down", class: "icon-5")
      end
    end
  end
end
