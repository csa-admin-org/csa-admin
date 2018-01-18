ActiveAdmin.register Payment do
  menu parent: 'Facturation', priority: 2
  actions :all, except: [:show, :edit, :update]

  scope :all, default: true
  scope :isr
  scope :manual

  index do
    column :id
    column :date, ->(p) { l p.date, format: :number }
    column :member, sortable: 'members.name'
    column :invoice_id, ->(p) { p.invoice_id ? auto_link(p.invoice, p.invoice_id) : '–' }
    column :amount, ->(p) { number_to_currency(p.amount) }
    column :type, ->(p) { status_tag p.type }
    actions
  end

  filter :id, as: :numeric
  filter :member,
    as: :select,
    collection: -> { Member.joins(:payments).order(:name).distinct }
  filter :invoice_id, as: :numeric
  filter :date

  sidebar 'Total', only: :index do
    all = collection.limit(nil)
    span 'Montant:'
    span number_to_currency(all.sum(:amount)), style: 'float: right; font-weight: bold;'
  end

  form do |f|
    f.inputs 'Details' do
      f.input :member, collection: Member.order(:name).distinct, include_blank: false
      f.input :date, as: :datepicker, include_blank: false
      f.input :amount, as: :number, min: 0, max: 99999.95, step: 0.05
    end
    f.actions
  end

  permit_params *%i[member_id date amount]

  controller do
    def build_resource
      super
      resource.amount ||= 0
      resource.date ||= Date.current
      resource
    end

    def scoped_collection
      Payment.includes(:member, :invoice)
    end
  end

  config.sort_order = 'date_desc'
  config.per_page = 50
end
