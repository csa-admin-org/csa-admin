class InvoiceMailer < ApplicationMailer
  def new_invoice(invoice)
    @invoice = invoice
    invoice_name = "Facture Rage de Vert ##{@invoice.id}.pdf"
    attachments.inline[invoice_name] = @invoice.pdf.file.read
    mail(
      to: invoice.member.emails,
      subject: "Rage de Vert: Nouvelle facture ##{@invoice.id}"
    )
  end
end
