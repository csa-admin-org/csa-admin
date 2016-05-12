class InvoiceMailer < ApplicationMailer
  attr_reader :invoice

  def new_invoice(invoice)
    @invoice = invoice
    attachments.inline[invoice_filename] = invoice_pdf
    mail(
      to: invoice.member.emails,
      subject: "Rage de Vert: Nouvelle facture ##{invoice.id}"
    )
  end

  def overdue_notice(invoice)
    @invoice = invoice
    attachments.inline[invoice_filename] = invoice_pdf
    subject = "Rappel ##{invoice.overdue_notices_count} facture ##{invoice.id}"
    mail(
      to: invoice.member.emails,
      subject: "Rage de Vert: #{subject}"
    )
  end

  private

  def invoice_filename
    "facture-rage-de-vert-#{invoice.id}.pdf"
  end

  def invoice_pdf
    invoice.pdf.file.read
  end
end
