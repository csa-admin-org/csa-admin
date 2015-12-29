class InvoiceMailer < ApplicationMailer
  attr_reader :invoice

  def new_invoice(invoice)
    @invoice = invoice
    attachments.inline[invoice_name] = invoice_pdf
    mail(
      to: invoice.member.emails,
      subject: "Rage de Vert: Nouvelle facture ##{invoice.id}"
    )
  end

  def overdue_notice(invoice)
    @invoice = invoice
    attachments.inline[invoice_name] = invoice_pdf
    subject = "Rappel ##{invoice.overdue_notices_count} facture ##{invoice.id}"
    mail(
      to: invoice.member.emails,
      subject: "Rage de Vert: #{subject}"
    )
  end

  private

  def invoice_name
    "Facture Rage de Vert ##{invoice.id}.pdf"
  end

  def invoice_pdf
    invoice.pdf.file.read
  end
end
