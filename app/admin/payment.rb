ActiveAdmin.register Payment do
  menu parent: :billing, priority: 2
  actions :all

  breadcrumb do
    if params[:action] == 'new'
      [link_to(Payment.model_name.human(count: 2), payments_path)]
    elsif params['action'] != 'index'
      links = [
        link_to(Member.model_name.human(count: 2), members_path),
        auto_link(payment.member),
        link_to(
          Payment.model_name.human(count: 2),
          payments_path(q: { member_id_eq: payment.member_id }, scope: :all))
      ]
      if params['action'].in? %W[edit]
        links << auto_link(payment)
      end
      links
    end
  end

  scope :all, default: true
  scope :qr
  scope :manual

  includes :member, :invoice
  index do
    column :id, ->(p) { auto_link p, p.id }
    column :date, ->(p) { l p.date, format: :number }
    column :member, sortable: 'members.name'
    column :invoice_id, ->(p) { p.invoice_id ? auto_link(p.invoice, p.invoice_id) : '–' }
    column :amount, ->(p) { cur(p.amount) }
    column :type, ->(p) { status_tag p.type }
    actions class: 'col-actions-3'
  end

  csv do
    column :id
    column :date
    column :amount
    column :member_id
    column :invoice_id
    column(:invoice_date) { |p| p.invoice&.date }
    column(:invoice_object) { |p|
      if type = p.invoice&.object_type
        t_invoice_object_type(type)
      end
    }
    column :type
  end

  filter :id, as: :numeric
  filter :member,
    as: :select,
    collection: -> { Member.joins(:payments).order(:name).distinct }
  filter :invoice_id, as: :numeric
  filter :amount
  filter :date
  filter :during_year,
    as: :select,
    collection: -> { fiscal_years_collection }

  sidebar :total, only: :index do
    all = collection.unscope(:includes).limit(nil)
    div class: 'content' do
      span t('active_admin.sidebars.amount')
      span cur(all.sum(:amount)), style: 'float: right; font-weight: bold;'
    end
  end

  sidebar :import, only: :index, if: -> { authorized?(:import, Payment) } do
    render('active_admin/payments/import')
  end

  sidebar_handbook_link('billing#paiements')

  collection_action :import, method: :post do
    authorize!(:import, Payment)
    Billing::CamtFile.process!(params.require(:file))
    redirect_to collection_path, notice: t('.flash.notice')
  rescue Billing::CamtFile::UnsupportedFileError
    redirect_to collection_path, alert: t('.flash.alert')
  end

  show do |payement|
    attributes_table do
      row :id
      row :member
      row :invoice
      row(:date) { l payement.date }
      row(:amount) { cur(payement.amount) }
      row(:created_at) { l payement.created_at, format: :long }
      row(:created_by)
      if payment.manual? && payment.updated?
        row(:updated_at) { l payement.updated_at, format: :long }
        row(:updated_by)
      end
    end

    active_admin_comments
  end

  form do |f|
    f.inputs t('.details') do
      f.input :member,
        collection: Member.order(:name).distinct,
        prompt: true,
        input_html: { disabled: f.object.invoice_id? }
      if f.object.invoice_id?
        f.input :member_id, as: :hidden
        f.input :invoice, collection: f.object.member.invoices, include_blank: true
      end
      f.input :date, as: :datepicker, prompt: true
      f.input :amount, as: :number, step: 0.05, min: -99999.95, max: 99999.95
      unless f.object.persisted?
        f.input :comment, as: :text, input_html: { rows: 4 }
      end
    end
    f.actions
  end

  permit_params(*%i[member_id invoice_id date amount comment])

  before_build do |payment|
    if params[:invoice_id]
      invoice = Invoice.find(params[:invoice_id])
      payment.invoice = invoice
      payment.member = invoice.member
    end
    payment.member_id ||= referer_filter(:member_id)
    payment.invoice_id ||= referer_filter(:invoice_id)
    payment.date ||= Date.current
    payment.amount ||= params[:amount] || 0
  end

  after_create do |payment|
    if payment.persisted? && payment.comment.present?
      ActiveAdmin::Comment.create!(
        resource: payment,
        body: payment.comment,
        author: current_admin,
        namespace: 'root')
    end
  end

  controller do
    include TranslatedCSVFilename
    include ApplicationHelper

    def apply_sorting(chain)
      super(chain).joins(:member).order('members.name')
    end
  end

  config.sort_order = 'date_desc'
  config.per_page = 50
end
