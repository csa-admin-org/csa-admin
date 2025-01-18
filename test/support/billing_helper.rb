# frozen_string_literal: true

module BillingHelper
  def force_invoice(member, **options)
    member.reload
    Billing::Invoicer.force_invoice!(member, **options)
  end

  def swiss_qr_ref(invoice)
    Billing::SwissQRReference.new(invoice)
  end

  def skip_invoice_pdf
    Thread.current[:skip_invoice_pdf] = true
  end

  def enable_invoice_pdf
    Thread.current[:skip_invoice_pdf] = false
  end
end
