ActiveAdmin.register Invoice do
  menu priority: 4

  scope :all, default: true
  # scope :open
  # scope :closed

  # scope :diff_name
  # scope :diff_zip, group: 2

  index_title = -> { "Factures (#{I18n.t("active_admin.scopes.#{current_scope.name.gsub(' ', '_').downcase}").downcase})" }

  index title: index_title do
    column :id
    column :date
    column :member
    column :amount, ->(invoice) { number_to_currency(invoice.amount) }
    column :balance, ->(invoice) { number_to_currency(invoice.balance) }
    # column :status, ->(invoice) { invoice.display_status }
    actions defaults: true do |invoice|
      link_to 'PDF', pdf_invoice_path(invoice), target: '_blank'
    end
  end

  # sidebar 'Dernière mise à jour', only: :index do
  #   l OldInvoice.maximum(:updated_at).in_time_zone
  # end

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
      row(:support_amount) { number_to_currency(invoice.support_amount) }
      row(:memberships_amount) { number_to_currency(invoice.memberships_amount) }
      row(:amount) { number_to_currency(invoice.amount) }
      row(:balance) { number_to_currency(invoice.balance) }
      # row(:status) { invoice.display_status }
      row(:updated_at) { l invoice.updated_at }
    end
  end

  member_action :pdf, method: :get do
    send_data resource.pdf.file.read,
      filename: "invoice-#{resource.id}.pdf",
      type: 'application/pdf',
      disposition: 'inline'
  end

  action_item :pdf, only: :show do
    link_to 'PDF', pdf_invoice_path(params[:id]), target: '_blank'
  end

  controller do
    def scoped_collection
      Invoice.includes(:member)
    end
  end

  config.per_page = 50
  config.sort_order = 'date_asc'
end
