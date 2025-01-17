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
end
