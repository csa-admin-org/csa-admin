ActiveAdmin.register Invoice do
  menu parent: :billing, priority: 1
  actions :all

  breadcrumb do
    if params[:action] == "new"
      [ link_to(Invoice.model_name.human(count: 2), invoices_path) ]
    elsif params["action"] != "index"
      [
        link_to(Member.model_name.human(count: 2), members_path),
        auto_link(invoice.member),
        link_to(
          Invoice.model_name.human(count: 2),
          invoices_path(q: { member_id_eq: invoice.member_id }, scope: :all))
      ]
    end
  end

  scope :all do |scope|
    scope.not_processing
  end
  scope :open_and_not_sent do |scope|
    scope.open.not_sent
  end
  scope :open, default: true
  scope :closed
  scope :canceled

  filter :id, as: :numeric
  filter :member,
    as: :select,
    collection: -> { Member.order(:name) }
  filter :entity_type,
    as: :check_boxes,
    collection: -> { entity_type_collection }
  filter :sent, as: :boolean
  filter :amount
  filter :balance, as: :numeric
  filter :overdue_notices_count
  filter :date
  filter :during_year,
    as: :select,
    collection: -> { fiscal_years_collection }

  includes :payments, pdf_file_attachment: :blob, member: :last_membership
  index download_links: -> {
    if !collection.respond_to?(:total_count) || collection.total_count <= ENV.fetch("INVOICE_PDFS_MAX_LIMIT", 500)
      [ :csv, :zip ]
    else
      [ :csv ]
    end
   } do
    column :id, ->(i) { auto_link i, i.id }
    column :date, ->(i) { l i.date, format: :number }
    column :member, sortable: "members.name"
    column :amount, ->(invoice) { cur(invoice.amount) }
    column :paid_amount, ->(invoice) { cur(invoice.paid_amount) }
    column :overdue_notices_count
    column :state, ->(invoice) { status_tag invoice.state }
    actions defaults: true, class: "col-actions-3" do |invoice|
      link_to_invoice_pdf(invoice)
    end
  end

  csv do
    column :id
    column :member_id
    column(:name) { |i| i.member.name }
    column(:emails) { |i| i.member.emails_array.join(", ") }
    column(:last_membership_ended_on) { |i| i.member.last_membership&.ended_on }
    column :date
    column(:entity) { |i| t_invoice_entity_type(i.entity_type) }
    column :amount_before_percentage
    column :amount_percentage
    column :amount
    if Current.acp.annual_fee?
      column :annual_fee
      column :memberships_amount
    end
    if Current.acp.vat_number?
      column :vat_rate
      column :amount_without_vat
      column :vat_amount
      column :amount_with_vat
    end
    column :paid_amount
    column :balance
    column :overdue_notices_count
    column :state, &:state_i18n_name
  end

  sidebar :total, only: :index do
    all = collection.unscope(:includes).offset(nil).limit(nil)
    div class: "content" do
      if Array(params.dig(:q, :entity_type_in)).include?("Membership") && Current.acp.annual_fee?
        div class: "total" do
          span Membership.model_name.human(count: 2)
          span cur(all.not_canceled.sum(:memberships_amount)), style: "float: right"
        end
        div class: "total" do
          span t("billing.annual_fees")
          span cur(all.not_canceled.sum(:annual_fee)), style: "float: right;"
        end
        div class: "totals" do
          span t("active_admin.sidebars.amount")
          span cur(all.not_canceled.sum(:amount)), style: "float: right; font-weight: bold;"
        end
      elsif params[:scope].in? [ "open", "all", "closed", nil ]
        div class: "total" do
          span t("billing.scope.paid") + ":"
          span cur(all.not_canceled.sum(:paid_amount)), style: "float: right;"
        end
        div class: "total" do
          amount = all.not_canceled.sum("amount - paid_amount")
          if amount >= 0
            span t("billing.scope.missing") + ":"
          else
            span t("active_admin.sidebars.overpaid")
          end
          span cur(amount), style: "float: right;"
        end
        div class: "totals" do
          span t("active_admin.sidebars.amount")
          span cur(all.not_canceled.sum(:amount)), style: "float: right; font-weight: bold;"
        end
      else
        div do
          span t("active_admin.sidebars.amount")
          span cur(all.sum(:amount)), style: "float: right; font-weight: bold;"
        end
      end
    end
  end

  sidebar :overdue_notice_not_sent_warning, only: :index, class: "warning", if: -> { !Current.acp.send_invoice_overdue_notice? } do
    div class: "actions warning" do
      handbook_icon_link("billing", anchor: "rappels")
    end

    div class: "content" do
      span t("active_admin.sidebars.overdue_notice_not_sent_warning_text_html")

      if authorized?(:create, Invoice)
        div class: "top-spacing" do
          button_to t(".send_overdue_notices"), send_overdue_notices_invoices_path,
            form: { data: { controller: "disable", disable_with_value: t(".sending") } },
            class: "full-width"
        end
      end
    end
  end

  collection_action :send_overdue_notices, method: :post do
    authorize!(:create, Invoice)
    Invoice.open.each { |i| InvoiceOverdueNoticer.perform(i) }
    redirect_to collection_path, notice: t("active_admin.flash.sending_overdue_notices")
  end

  sidebar_handbook_link("billing")

  show do |invoice|
    columns do
      column do
        panel link_to(t(".direct_payments"), payments_path(q: { invoice_id_eq: invoice.id, member_id_eq: invoice.member_id }, scope: :all)) do
          payments = invoice.payments.order(:date)
          if payments.none?
            em t(".no_payments")
          else
            table_for(payments, class: "table-payments") do
              column(:date) { |p| auto_link p, l(p.date, format: :number) }
              column(:amount) { |p| cur(p.amount) }
              column(:type) { |p| status_tag p.type }
            end
          end
        end
        if invoice.items.any?
          panel InvoiceItem.model_name.human(count: 2) do
            table_for(invoice.items, class: "table-payments") do
              column(:description) { |ii| ii.description }
              column(:amount) { |ii| cur(ii.amount) }
            end
          end
        end
        if Rails.env.production? && !invoice.processing?
          panel "PDF" do
            div class: "actions" do
              icon_link(:pdf_file, "PDF", invoice_pdf_url(invoice), target: "_blank")
            end
            div do
              link_to_invoice_pdf(invoice) do
                image_tag invoice.pdf_file.representation(resize_to_limit: [ 1000, 1000 ]), width: "100%"
              end
            end
          end
        end
      end

      column do
        attributes_table do
          row :id
          row :member
          row(:entity) { display_entity(invoice) }
          if invoice.acp_share_type?
            row(:acp_shares_number)
          end
          if invoice.activity_participation_type?
            row(:paid_missing_activity_participations)
          end
          row(:date) { l invoice.date }
          row(:state) { status_tag invoice.state }
          row(:sent) { status_tag invoice.sent_at? }
          row(:created_at) { l(invoice.created_at, format: :long) }
          row(:created_by)
          if invoice.sent_at?
            row(:sent_at) { l(invoice.sent_at, format: :long) if invoice.sent_at }
            row(:sent_by)
          end
          if invoice.closed?
            row(:closed_at) { l(invoice.closed_at, format: :long) if invoice.closed_at }
            row(:closed_by)
          elsif invoice.canceled?
            row(:canceled_at) { l invoice.canceled_at, format: :long }
            row(:canceled_by)
          end
        end

        attributes_table title: Invoice.human_attribute_name(:amount) do
          if invoice.amount_percentage?
            row(:amount_before_percentage) { cur(invoice.amount_before_percentage) }
            row(:amount_percentage) { number_to_percentage(invoice.amount_percentage, precision: 1) }
          end
          row(:amount) { cur(invoice.amount) }
          row(:paid_amount) { cur(invoice.paid_amount) }
          row(:balance) { cur(invoice.balance) }
        end

        attributes_table title: Invoice.human_attribute_name(:overdue_notices_count) do
          row :overdue_notices_count
          row(:overdue_notice_sent_at) { l invoice.overdue_notice_sent_at if invoice.overdue_notice_sent_at }
        end

        active_admin_comments
      end
    end
  end

  action_item :cancel_and_edit_shop_order, only: :show, if: -> { invoice.shop_order_type? && authorized?(:cancel, invoice.entity) } do
    button_to t(".cancel_and_edit_shop_order"), cancel_shop_order_path(invoice.entity),
      form: { data: { controller: "disable", disable_with_value: t("formtastic.processing") } },
      data: { confirm: t(".cancel_action_confirm") }
  end

  action_item :pdf, only: :show, if: -> { !invoice.processing? } do
    link_to_invoice_pdf(resource)
  end

  action_item :new_payment, only: :show, if: -> { authorized?(:create, Payment) } do
    link_to t(".new_payment"), new_payment_path(
      invoice_id: invoice.id, amount: [ invoice.amount, invoice.missing_amount ].min)
  end

  action_item :refund, only: :show, if: -> { invoice.can_refund? } do
    acp_shares_number = [ invoice.acp_shares_number, invoice.member.acp_shares_number ].min
    link_to t(".refund"),
      new_invoice_path(member_id: invoice.member_id, acp_shares_number: -acp_shares_number, anchor: "acp_share")
  end

  action_item :send_email, only: :show, if: -> { authorized?(:send_email, resource) } do
    button_to t(".send_email"), send_email_invoice_path(resource),
      form: { data: { controller: "disable", disable_with_value: t("formtastic.processing") } }
  end

  action_item :mark_as_sent, only: :show, if: -> { authorized?(:mark_as_sent, resource) } do
    button_to t(".mark_as_sent"), mark_as_sent_invoice_path(resource),
      form: { data: { controller: "disable", disable_with_value: t("formtastic.processing") } }
  end

  action_item :cancel, only: :show, if: -> { authorized?(:cancel, resource) && resource.entity_type != "Shop::Order" } do
    button_to t(".cancel_invoice"), cancel_invoice_path(resource),
      form: { data: { controller: "disable", disable_with_value: t("formtastic.processing") } },
      data: { confirm: t(".link_confirm") }
  end

  member_action :pdf, method: :get, if: -> { Rails.env.development? } do
    Tempfile.open do |file|
      I18n.with_locale(resource.member.language) do
        pdf = PDF::Invoice.new(resource)
        pdf.render_file(file.path)
        PDF::InvoiceCancellationStamp.stamp!(file.path)
      end
      send_file file,
        filename: "invoice-#{resource.id}.pdf",
        type: "application/pdf",
        disposition: "inline"
    end
  end

  member_action :send_email, method: :post do
    resource.send!
    redirect_to resource_path, notice: t(".flash.notice")
  end

  member_action :mark_as_sent, method: :post do
    resource.mark_as_sent!
    redirect_to resource_path, notice: t("flash.actions.update.notice")
  end

  member_action :cancel, method: :post do
    resource.cancel!
    redirect_to resource_path, notice: t(".flash.notice")
  end

  form do |f|
    f.inputs t(".details") do
      f.input :member,
        collection: Member.order(:name).distinct,
        prompt: true,
        input_html: { onchange: "self.location='#{new_invoice_path}?member_id='+$(this).val();" }
      f.hidden_field :entity_id
      f.hidden_field :entity_type
      f.input :date, as: :date_picker
      unless f.object.persisted?
        f.input :comment, as: :text, input_html: { rows: 4 }
      end
    end
    tabs do
      unless f.object.persisted?
        if Current.acp.feature?("activity")
          tab activities_human_name, id: "activity_participation" do
            f.inputs do
              if f.object.entity.is_a?(ActivityParticipation)
                li(class: "refused_activity_participation") do
                  parts = []
                  parts << link_to(
                    t("active_admin.resource.new.refused_activity_participation", date: f.object.entity.activity.date),
                    activity_participation_path(f.object.entity_id))
                  parts << " – "
                  parts << link_to(
                    t(".erase").downcase,
                    new_invoice_path(member_id: f.object.member_id))
                  parts.join.html_safe
                end
              end
              f.input :paid_missing_activity_participations, as: :number, step: 1
              f.input :activity_price, as: :number, min: 0, max: 99999.95, step: 0.05, hint: true
            end
          end
        end
        if Current.acp.share?
          tab t_invoice_entity_type("ACPShare"), id: "acp_share" do
            f.inputs do
              f.input :acp_shares_number, as: :number, step: 1
            end
          end
        end
      end
      tab t_invoice_entity_type("Other"), id: "other" do
        f.inputs do
          f.semantic_errors :items
          if Current.acp.vat_number?
            f.input :vat_rate, as: :number, min: 0, max: 100, step: 0.01
          end
          f.has_many :items, new_record: t(".has_many_new_invoice_item"), allow_destroy: true do |ff|
            ff.input :description
            ff.input :amount, as: :number, step: 0.05, min: 0, max: 99999.95
          end
        end
      end
    end
    f.actions
  end

  permit_params \
    :member_id,
    :entity_id,
    :entity_type,
    :date,
    :comment,
    :paid_missing_activity_participations,
    :activity_price,
    :acp_shares_number,
    :vat_rate,
    items_attributes: %i[id description amount _destroy]

  before_build do |invoice|
    if params[:activity_participation_id]
      ap = ActivityParticipation.find(params[:activity_participation_id])
      invoice.member = ap.member
      invoice.entity = ap
      invoice.paid_missing_activity_participations = ap.participants_count
    elsif params[:member_id]
      member = Member.find(params[:member_id])
      invoice.member = member
    end
    if params[:acp_shares_number]
      invoice.acp_shares_number ||= params[:acp_shares_number]
    end

    invoice.member_id ||= referer_filter(:member_id)
    invoice.date ||= Date.current
  end

  after_create do |invoice|
    if invoice.persisted? && invoice.comment.present?
      ActiveAdmin::Comment.create!(
        resource: invoice,
        body: invoice.comment,
        author: current_admin,
        namespace: "root")
    end
  end

  before_action only: :index do
    if params[:scope] == "open_and_not_sent"
      params[:q] ||= {}
      params[:q][:sent_eq] = false
    end
  end

  controller do
    include TranslatedCSVFilename
    include ApplicationHelper

    after_action :refresh_invoice, only: :update

    def index
      super do |format|
        format.zip do
          zip = InvoicesPDFZipper.zip(collection)
          send_file zip.path,
            type: "application/zip",
            filename: "invoices-#{Date.current}.zip"
        end
      end
    end

    private

    # Skip pagination when downloading a zip file
    def apply_pagination(chain)
      return chain if params["format"] == "zip"

      super
    end

    def apply_sorting(chain)
      super(chain).joins(:member).order("members.name", id: :desc)
    end

    def refresh_invoice
      if resource.valid?
        resource.attach_pdf
        Billing::PaymentsRedistributor.redistribute!(resource.member_id)
      end
    end
  end

  config.sort_order = "date_desc"
end
