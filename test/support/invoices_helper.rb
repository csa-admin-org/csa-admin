# frozen_string_literal: true

module InvoicesHelper
  def create_invoice(attrs = {})
    invoice = Invoice.create!({
      member: members(:john),
      date: Date.today
    }.merge(attrs))
    perform_enqueued_jobs
    invoice.reload
    invoice
  end

  def skip_invoice_pdf
    Thread.current[:skip_invoice_pdf] = true
  end

  def enable_invoice_pdf
    Thread.current[:skip_invoice_pdf] = false
  end
end
