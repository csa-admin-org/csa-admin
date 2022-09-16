class InvoiceMailer < ApplicationMailer
  include Templatable

  def created_email
    invoice = params[:invoice]
    member = invoice.member
    attach_invoice_pdf!
    template_mail(member,
      to: to(member),
      'member' => Liquid::MemberDrop.new(member),
      'invoice' => Liquid::InvoiceDrop.new(invoice))
  end

  def overdue_notice_email
    invoice = params[:invoice]
    member = invoice.member
    attach_invoice_pdf!
    @subject_class = 'warning'
    template_mail(member,
      to: to(member),
      'member' => Liquid::MemberDrop.new(member),
      'invoice' => Liquid::InvoiceDrop.new(invoice))
  end

  private

  def to(member)
    member.billing_email.presence || member.emails_array
  end

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
