class Members::BillingController < Members::BaseController
  # GET /billing
  def index
    invoices = current_member.invoices.includes(pdf_file_attachment: :blob)
    @open_invoices = invoices.open.order(date: :desc)
    @billing_history = (invoices.history + current_member.payments).sort_by(&:date).reverse
  end
end
