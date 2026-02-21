# frozen_string_literal: true

class InvoiceMailer < ApplicationMailer
  include Templatable

  before_action :set_context

  def created_email
    attach_invoice_pdf!
    attach_attachments!
    invoice_email
  end

  def cancelled_email
    invoice_email
  end

  def overdue_notice_email
    attach_invoice_pdf!
    @subject_class = "warning"
    invoice_email
  end

  private

  def set_context
    @invoice = params[:invoice]
    @member = @invoice.member
  end

  def invoice_email
    template_mail(@member,
      to: @member.billing_emails,
      "member" => Liquid::MemberDrop.new(@member),
      "invoice" => Liquid::InvoiceDrop.new(@invoice))
  end

  def attach_invoice_pdf!
    return unless @invoice.is_a?(Invoice)

    attachments[@invoice.pdf_filename] = {
      mime_type: "application/pdf",
      content: @invoice.pdf_file.download
    }
  end

  def attach_attachments!
    return unless @invoice.attachments.present?

    @invoice.attachments.map(&:file).each { |file|
      filename =
        ActiveSupport::Inflector.transliterate(file.filename.to_s.gsub(/"/, "'"))
      attachments[filename] = {
        mime_type: file.content_type,
        content: file.download
      }
    }
  end
end
