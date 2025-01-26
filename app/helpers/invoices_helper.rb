# frozen_string_literal: true

module InvoicesHelper
  def entity_type_collection
    Invoice.used_entity_types.map { |type|
      [ t_invoice_entity_type(type), type ]
    }.sort_by { |a| a.first }
  end

  def display_entity(invoice, link: true)
    if link && invoice.entity
      auto_link invoice.entity
    elsif invoice.entity_type == "Membership"
      t("billing.membership_entity",
        fiscal_year: invoice.entity.fiscal_year,
        number: invoice.memberships_amount_description[/#\d+\z/])
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

    link_to pdf_invoice_path(invoice), **options, title: title, target: "_blank" do
      if block
        block.call
      else
        icon "file-pdf", class: "h-5 w-5", library: "own"
      end
    end
  end
end
