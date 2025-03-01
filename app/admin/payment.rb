# frozen_string_literal: true

ActiveAdmin.register Payment do
  menu parent: :navbilling, priority: 2
  actions :all

  breadcrumb do
    if params[:action] == "new"
      [ link_to(Payment.model_name.human(count: 2), payments_path) ]
    elsif params["action"] != "index"
      links = [
        link_to(Member.model_name.human(count: 2), members_path),
        auto_link(resource.member),
        link_to(
          Payment.model_name.human(count: 2),
          payments_path(q: { member_id_eq: resource.member_id }, scope: :all))
      ]
      if params["action"].in? %W[edit]
        links << auto_link(resource)
      end
      links
    end
  end

  scope :all, default: true
  scope :auto
  scope :manual

  filter :during_year,
    as: :select,
    collection: -> { fiscal_years_collection }
  filter :date
  filter :id, as: :numeric
  filter :member,
    as: :select,
    collection: -> { Member.joins(:payments).order(:name).distinct }
  filter :invoice_id, as: :numeric
  filter :amount

  includes :member, :invoice
  index do
    column :id, ->(p) { auto_link p, p.id }
    column :member, sortable: "members.name"
    column :date, ->(p) { l p.date, format: :number }, class: "text-right tabular-nums"
    column :invoice_id, ->(p) { p.invoice_id ? auto_link(p.invoice, p.invoice_id) : "–" }, class: "text-right"
    column :amount, ->(p) { cur(p.amount) }, class: "text-right tabular-nums"
    column :type, ->(p) { status_tag p.type }, class: "text-right"
    actions do |payment|
      link_to_invoice_pdf(payment.invoice) if payment.invoice_id?
    end
  end

  csv do
    column :id
    column :date
    column :amount
    column :member_id
    column :invoice_id
    column(:invoice_date) { |p| p.invoice&.date }
    column(:invoice_entity) { |p|
      if type = p.invoice&.entity_type
        t_invoice_entity_type(type)
      end
    }
    column :type
  end

  sidebar :total, only: :index, if: -> { params[:q] } do
    side_panel t(".total") do
      all = collection.unscope(:includes).offset(nil).limit(nil)
      div number_line(t(".amount"), cur(all.sum(:amount)))
    end
  end

  sidebar :import, only: :index, if: -> { authorized?(:import, Payment) } do
    side_panel t(".import") do
      render("active_admin/payments/import")
    end
  end

  sidebar_handbook_link("billing#paiements")

  collection_action :import, method: :post do
    authorize!(:import, Payment)
    if Billing.import_payments(params.require(:file))
      redirect_to collection_path, notice: t(".flash.notice")
    else
      redirect_to collection_path, alert: t(".flash.alert")
    end
  end

  show do |payment|
    columns do
      column do
        if payment.invoice_id?
          panel auto_link(payment.invoice), action: icon_file_link(:pdf, pdf_invoice_path(payment.invoice), target: "_blank") do
            div class: "p-2" do
              link_to_invoice_pdf(payment.invoice) do
                render "invoice_preview", invoice: payment.invoice
              end
            end
          end
        else
          panel Invoice.model_name.human do
            div class: "missing-data" do
              t(".no_invoice")
            end
          end
        end
      end
      column do
        panel t(".details") do
          attributes_table do
            row :id
            row :member
            row(:date) { l payment.date }
            row(:amount) { cur(payment.amount) }
            row(:created_at) { l(payment.created_at, format: :medium) }
            row(:created_by)
            if payment.manual? && payment.updated?
              row(:updated_at) { l(payment.updated_at, format: :medium) }
              row(:updated_by)
            end
          end
        end

        active_admin_comments_for(payment)
      end
    end
  end

  form do |f|
    f.inputs t(".details") do
      if f.object.invoice_id?
        f.input :member_id, as: :hidden
      end
      f.input :member,
        collection: Member.order(:name).distinct,
        prompt: true,
        input_html: { disabled: f.object.invoice_id? }
      if f.object.invoice_id?
        f.input :invoice, collection: f.object.member.invoices, include_blank: true
      end
      f.input :date, as: :date_picker, prompt: true
      f.input :amount, as: :number, step: 0.01, min: -99999.99, max: 99999.99
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
        namespace: "root")
    end
  end

  controller do
    include TranslatedCSVFilename
    include ApplicationHelper

    def apply_sorting(chain)
      super(chain).joins(:member).order("LOWER(members.name)", id: :desc)
    end
  end

  order_by("members.name") do |clause|
    "LOWER(members.name) #{clause.order}"
  end

  config.sort_order = "date_desc"
end
