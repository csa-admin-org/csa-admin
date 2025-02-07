# frozen_string_literal: true

class InvoiceMailer < ApplicationMailer
  include Templatable

  def created_email
    invoice = params[:invoice]
    member = invoice.member
    attach_invoice_pdf!
    attach_attachments!
    template_mail(member,
      to: member.billing_emails,
      tag: "invoice-created",
      "member" => Liquid::MemberDrop.new(member),
      "invoice" => Liquid::InvoiceDrop.new(invoice))
  end

  def cancelled_email
    invoice = params[:invoice]
    member = invoice.member
    template_mail(member,
      to: member.billing_emails,
      tag: "invoice-cancelled",
      "member" => Liquid::MemberDrop.new(member),
      "invoice" => Liquid::InvoiceDrop.new(invoice))
  end

  def overdue_notice_email
    invoice = params[:invoice]
    member = invoice.member
    attach_invoice_pdf!
    @subject_class = "warning"
    template_mail(member,
      to: member.billing_emails,
      tag: "invoice-overdue-notice",
      "member" => Liquid::MemberDrop.new(member),
      "invoice" => Liquid::InvoiceDrop.new(invoice))
  end

  private

  def attach_invoice_pdf!
    invoice = params[:invoice]
    filename = [
      Invoice.model_name.human.downcase.parameterize,
      Tenant.current,
      invoice.id
    ].join("-") + ".pdf"
    attachments[filename] = {
      mime_type: "application/pdf",
      content: invoice.pdf_file.download
    }
  end

  def attach_attachments!
    return unless params[:invoice].attachments.present?

    params[:invoice].attachments.map(&:file).each { |file|
      filename =
        ActiveSupport::Inflector.transliterate(file.filename.to_s.gsub(/"/, "'"))
      attachments[filename] = {
        mime_type: file.content_type,
        content: file.download
      }
    }
  end
end
