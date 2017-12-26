ActiveAdmin.register Invoice do
  menu priority: 4
  actions :all

  scope :all, default: true
  scope :not_sent
  scope :open
  scope :with_overdue_notice
  scope :closed

  index do
    column :id
    column :date, ->(i) { l i.date, format: :number }
    column :member
    column :amount, ->(invoice) { number_to_currency(invoice.amount) }
    column :balance, ->(invoice) { number_to_currency(invoice.balance) }
    column :overdue_notices_count
    column :status, ->(invoice) { status_tag invoice.status }
    actions defaults: true do |invoice|
      link_to 'PDF', pdf_invoice_path(invoice), class: 'pdf_link', target: '_blank'
    end
  end

  filter :id, as: :numeric
  filter :member,
    as: :select,
    collection: -> { Member.joins(:invoices).order(:last_name).distinct }
  filter :date

  show do |invoice|
    attributes_table do
      row :id
      row :member
      row(:date) { l invoice.date }
      row(:sent_at) { l invoice.sent_at if invoice.sent_at }
      row(:amount) { number_to_currency(invoice.amount) }
      row(:isr_balance) { number_to_currency(invoice.isr_balance) }
      row(:manual_balance) { number_to_currency(invoice.manual_balance) }
      row(:balance) { number_to_currency(invoice.balance) }
      row(:status) { invoice.display_status }
      row :overdue_notices_count
      row(:overdue_notice_sent_at) { l invoice.overdue_notice_sent_at if invoice.overdue_notice_sent_at }
      row :note
      row(:updated_at) { l invoice.updated_at }
    end
  end

  form do |f|
    f.inputs :manual_balance, as: :number
    f.inputs :note, input_html: { rows: 3 }
    f.actions
  end

  permit_params %i[manual_balance note]

  member_action :pdf, method: :get do
    send_data resource.pdf.file.read,
      filename: "invoice-#{resource.id}.pdf",
      type: 'application/pdf',
      disposition: 'inline'
  end

  member_action :send_email, method: :post do
    resource.send_email
    redirect_to resource_path, notice: "Email envoyé!"
  end

  action_item :pdf, only: :show do
    link_to 'PDF', pdf_invoice_path(params[:id]), target: '_blank'
  end
  action_item :send_email, only: :show do
    if resource.sendable?
      link_to 'Envoyer email', send_email_invoice_path(resource), method: :post
    end
  end

  controller do
    def scoped_collection
      Invoice.includes(:member)
    end
  end

  config.per_page = 50
  config.sort_order = 'date_asc'
end
