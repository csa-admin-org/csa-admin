class InvoiceMailer < ApplicationMailer
  include Templatable

  def created_email
    member = params[:member]
    invoice = params[:invoice]
    attach_invoice_pdf!
    template_mail(member,
      'member' => Liquid::MemberDrop.new(member),
      'invoice' => Liquid::InvoiceDrop.new(invoice))
  end

  def overdue_notice_email
    member = params[:member]
    invoice = params[:invoice]
    attach_invoice_pdf!
    template_mail(member,
      'member' => Liquid::MemberDrop.new(member),
      'invoice' => Liquid::InvoiceDrop.new(invoice))
  end

  private

  def attach_invoice_pdf!
    invoice = params[:invoice]
    filename = [
      Invoice.model_name.human.downcase.parameterize,
      Current.acp.tenant_name,
      invoice.id
    ].join('-') + '.pdf'
    attachments[filename] = {
      mime_type: 'application/pdf',
      content: invoice.pdf_file.download
    }
  end
end
