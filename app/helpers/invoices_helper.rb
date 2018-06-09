module InvoicesHelper
  def object_type_collection
    Invoice::OBJECT_TYPES.map { |type|
      [t_invoice_object_type(type), type]
    }.sort_by { |a| a.first }
  end

  def display_object(invoice)
    if invoice.object
      auto_link invoice.object
    else
      t_invoice_object_type(invoice.object_type)
    end
  end

  private

  def t_invoice_object_type(type)
    case type
    when 'HalfdayParticipation' then halfday_human_name
    else
      type.constantize.model_name.human
    end
  rescue NameError
    I18n.t("invoices.object_type.#{type.underscore}")
  end
end
