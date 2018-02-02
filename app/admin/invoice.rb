ActiveAdmin.register Invoice do
  menu parent: 'Facturation', priority: 1
  actions :all, except: [:new, :create, :edit, :update, :destroy]

  scope :all
  scope :not_sent
  scope :open, default: true
  scope :with_overdue_notice
  scope :closed
  scope :canceled

  includes :member, pdf_file_attachment: :blob
  index do
    column :id, ->(i) { auto_link i, i.id }
    column :date, ->(i) { l i.date, format: :number }
    column :member
    column :amount, ->(invoice) { number_to_currency(invoice.amount) }
    column :balance, ->(invoice) { number_to_currency(invoice.balance) }
    column 'Rap.',  ->(invoice) { invoice.overdue_notices_count }
    column :state, ->(invoice) { status_tag invoice.state }
    actions defaults: true do |invoice|
      link_to 'PDF', rails_blob_path(invoice.pdf_file, disposition: 'attachment'), class: 'pdf_link'
    end
  end

  filter :id, as: :numeric
  filter :member,
    as: :select,
    collection: -> { Member.joins(:invoices).order(:name).distinct }
  filter :date

  show do |invoice|
    columns do
      column do
        panel link_to('Paiements directs', payments_path(q: { invoice_id_equals: invoice.id, member_id_eq: invoice.member_id }, scope: :all)) do
          payments = invoice.payments.order(:date)
          if payments.none?
            em 'Aucun paiement'
          else
            table_for(payments, class: 'table-payments') do |payment|
              column(:date) { |p| l(p.date, format: :number) }
              column(:amount) { |p| number_to_currency(p.amount) }
              column(:type) { |p| status_tag p.type }
            end
          end
        end
      end

      column do
        attributes_table do
          row :id
          row :member
          row(:date) { l invoice.date }
          row(:state) { status_tag invoice.state }
          row(:sent_at) { l invoice.sent_at if invoice.sent_at }
          row(:updated_at) { l invoice.updated_at }
        end

        attributes_table title: 'Montant' do
          row(:amount) { number_to_currency(invoice.amount) }
          row(:balance) { number_to_currency(invoice.balance) }
        end

        attributes_table title: 'Rappels' do
          row :overdue_notices_count
          row(:overdue_notice_sent_at) { l invoice.overdue_notice_sent_at if invoice.overdue_notice_sent_at }
        end

        active_admin_comments
      end
    end
  end

  action_item :pdf, only: :show do
    link_to 'PDF', rails_blob_path(resource.pdf_file, disposition: 'attachment')
  end

  action_item :send_email, only: :show, if: -> { authorized?(:send_email, resource) } do
    link_to 'Envoyer', send_email_invoice_path(resource), method: :post
  end

  action_item :cancel, only: :show, if: -> { authorized?(:cancel, resource) } do
    link_to 'Annuler', cancel_invoice_path(resource), method: :post
  end

  member_action :send_email, method: :post do
    resource.send!
    redirect_to resource_path, notice: "Email envoyé!"
  end

  member_action :cancel, method: :post do
    resource.cancel!
    redirect_to resource_path, notice: "Facture annulée"
  end

  config.per_page = 50
  config.sort_order = 'date'
end
