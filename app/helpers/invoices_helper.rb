module InvoicesHelper
  def object_type_collection
    Invoice.object_types.map { |type|
      [t_invoice_object_type(type), type]
    }.sort_by { |a| a.first }
  end

  def display_object(invoice, link: true)
    if link && invoice.object
      auto_link invoice.object, t_invoice_object_type(invoice.object_type)
    else
      t_invoice_object_type(invoice.object_type)
    end
  end

  def t_invoice_object_type(type)
    case type
    when 'ActivityParticipation' then activity_human_name
    else
      type.constantize.model_name.human
    end
  rescue NameError
    I18n.t("invoices.object_type.#{type.underscore}")
  end

  def link_to_invoice_pdf(invoice, title: 'PDF')
    return unless invoice
    return if invoice.processing?

    link_to title, rails_blob_path(invoice.pdf_file, disposition: 'attachment'), class: 'pdf_link'
  end
end
