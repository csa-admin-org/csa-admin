# frozen_string_literal: true

ActiveAdmin.register Invoice do
  menu parent: :navbilling, priority: 1
  actions :all

  breadcrumb do
    if params[:action] == "new"
      [ link_to(Invoice.model_name.human(count: 2), invoices_path) ]
    elsif params["action"] != "index"
      [
        link_to(Member.model_name.human(count: 2), members_path),
        auto_link(resource.member),
        link_to(
          Invoice.model_name.human(count: 2),
          invoices_path(q: { member_id_eq: resource.member_id }, scope: :all))
      ]
    end
  end

  scope :all do |scope|
    scope.not_processing
  end
  scope :open, default: true
  scope :closed
  scope :canceled

  filter :during_year,
    as: :select,
    collection: -> { fiscal_years_collection }
  filter :date
  filter :id, as: :numeric
  filter :member,
    as: :select,
    collection: -> { members_collection(collection) }
  filter :membership,
    as: :select,
    collection: -> { Membership.where(member_id: params.dig(:q, :member_id_eq)).all.map { |m| [ m.id, m.id ] } },
    if: ->(a) { params.dig(:q, :member_id_eq).present? && params.dig(:q, :entity_type_eq) == "Membership" }
  filter :entity_type,
    as: :check_boxes,
    collection: -> { entity_type_collection }
  filter :sent, as: :boolean
  filter :sepa, as: :boolean, if: ->(a) { Current.org.sepa? }
  filter :amount
  filter :balance, as: :numeric
  filter :overdue_notices_count
  filter :activity_participations_fiscal_year,
    label: -> {
      Invoice.human_attribute_name(activity_scoped_attribute(:missing_participations_fiscal_year))
    },
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
    column :id
    column :date, ->(i) { l i.date, format: :number }, class: "text-right tabular-nums"
    column :member, sortable: "members.name"
    column :amount, ->(invoice) { cur(invoice.amount) }, class: "text-right tabular-nums"
    column :paid_amount, ->(invoice) { invoice.canceled? ? "–" : cur(invoice.paid_amount) }, class: "text-right tabular-nums"
    column :overdue_notices_count, ->(invoice) { invoice.sepa? ? "–" : invoice.overdue_notices_count }, class: "text-right"
    column :state, ->(invoice) { status_tag invoice.state }, class: "text-right"
    actions do |invoice|
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
    if Current.org.annual_fee?
      column :annual_fee
      column :memberships_amount
    end
    if Current.org.vat_number?
      column :vat_rate
      column :amount_without_vat
      column :vat_amount
      column :amount_with_vat
    end
    if feature?("activity")
      column :missing_activity_participations_fiscal_year
      column :missing_activity_participations_count
    end
    column :paid_amount
    column :balance
    column :overdue_notices_count
    column :overdue_notice_sent_at
    column :state, &:state_i18n_name
    column :created_at
    column(:created_by) { |i| i.created_by&.name }
    column :canceled_at
    column(:canceled_by) { |i| i.canceled_by&.name }
    column :closed_at
    column(:closed_by) { |i| i.closed_by&.name }
  end

  sidebar :open_and_not_sent, only: :index, if: -> { params[:scope].in?([ nil, "open" ]) && Invoice.open.not_sent.any? } do
    side_panel nil, class: "warning" do
      para do
        t("active_admin.shared.sidebar_section.invoice_open_not_sent_text_html",
          count: Invoice.open.not_sent.count,
          url: invoices_path(scope: "open", q: { sent_eq: false }))
      end
    end
  end

  sidebar :total, only: :index do
    side_panel t(".total") do
      all = collection.unscope(:includes).offset(nil).limit(nil)

      if Array(params.dig(:q, :entity_type_in)).include?("Membership") && Current.org.annual_fee?
        div number_line(Membership.model_name.human(count: 2), cur(all.sum(:memberships_amount)), bold: false)
        div number_line(t("billing.annual_fees"), cur(all.sum(:annual_fee)), bold: false)
        div number_line(t(".amount"), cur(all.sum(:amount)), border_top: true)
      elsif params[:scope].in? [ "open", "all", "closed", nil ]
        div number_line(t("billing.scope.paid"), cur(all.not_canceled.sum(:paid_amount)), bold: false)
        amount = all.not_canceled.sum("amount - paid_amount")
        title = amount >= 0 ? t("billing.scope.missing") : t(".overpaid")
        div number_line(title, cur(amount), bold: false)
        div number_line(t(".amount"), cur(all.not_canceled.sum(:amount)), border_top: true)
      else
        div number_line(t(".amount"), cur(all.sum(:amount)))
      end
    end
  end

  sidebar :sepa_pain, only: :index, if: -> { params[:scope].in?([ nil, "all", "open" ]) && collection.offset(nil).limit(nil).open.sepa.any? && !Current.org.bank_connection? } do
    side_panel "SEPA" do
      para t(".sepa_pain_text_html",
        count: collection.offset(nil).limit(nil).open.sepa.count,
        url: invoices_path(scope: "open", q: { sepa_eq: true }))
      div class: "mt-3 flex justify-center" do
        link_to sepa_pain_all_invoices_path(params.permit(:scope, q: {})), class: "btn btn-sm", title: Billing::SEPADirectDebit::SCHEMA,  data: { turbo: false } do
          icon("document-arrow-down", class: "size-4 mr-2") + t(".sepa_pain")
        end
      end
    end
  end

  sidebar :overdue_notice_not_sent_warning, only: :index, if: -> { !Current.org.send_invoice_overdue_notice? } do
    side_panel t(".overdue_notice_not_sent_warning"), action: handbook_icon_link("billing", anchor: "overdue_notice"), class: "warning" do
      para do
        if Current.org.bank_connection?
          t(".overdue_notice_not_sent_warning_mail_template_not_active_text_html")
        else
          t(".overdue_notice_not_sent_warning_no_automatic_payment_processing_text_html")
        end
      end
      if authorized?(:create, Invoice)
        div class: "mt-3 " do
          button_to send_overdue_notices_invoices_path,
            form: { class: "flex justify-center", data: { controller: "disable", disable_with_value: t(".sending") } },
            class: "btn btn-sm" do
              icon("paper-airplane", class: "size-4 mr-2") + t(".send_overdue_notices")
            end
        end
      end
    end
  end

  collection_action :send_overdue_notices, method: :post do
    authorize!(:create, Invoice)
    Invoice.open.each { |i| InvoiceOverdueNotice.deliver(i) }
    redirect_to collection_path, notice: t("active_admin.flash.sending_overdue_notices")
  end

  sidebar_handbook_link("billing")

  show do |invoice|
    columns do
      column do
        panel link_to(t(".direct_payments"), payments_path(q: { invoice_id_eq: invoice.id, member_id_eq: invoice.member_id }, scope: :all)), count: invoice.payments.count do
          payments = invoice.payments.order(:date)
          if payments.none?
            div(class: "missing-data") { t(".no_payments") }
          else
            table_for(payments, class: "table-auto") do
              column(:date) { |p| auto_link p, l(p.date, format: :number), aria: { label: "show" } }
              column(:amount, class: "text-right tabular-nums") { |p| cur(p.amount) }
              column(:type, class: "text-right") { |p| status_tag p.type }
            end
          end
        end
        if invoice.items.any?
          panel InvoiceItem.model_name.human(count: 2), count: invoice.items.count do
            table_for(invoice.items, class: "table-auto") do
              column(:description) { |ii| ii.description }
              column(:amount, class: "text-right tabular-nums") { |ii| cur(ii.amount) }
            end
          end
        end
        if invoice.processing?
          panel "PDF", data: { controller: "auto-refresh" } do
            div class: "p-2" do
              render "invoice_preview", invoice: invoice
            end
          end
        else
          panel "PDF", action: icon_file_link(:pdf, pdf_invoice_path(invoice), target: "_blank") do
            div class: "p-2" do
              link_to_invoice_pdf(invoice) do
                render "invoice_preview", invoice: invoice
              end
            end
          end
        end
      end

      column do
        panel t(".details") do
          attributes_table do
            row :id
            row :member
            row(:entity) { display_entity(invoice) }
            if invoice.share_type?
              row(:shares_number)
            end
            if invoice.activity_participation_type?
              row(:missing_activity_participations_fiscal_year)
              row(:membership) {
                if membership = invoice.member.membership(invoice.missing_activity_participations_fiscal_year)
                  auto_link membership
                end
              }
              row(:missing_activity_participations_count)
            end
            row(:date) { l invoice.date, format: :medium }
            row(:sent) { status_tag invoice.sent_at? }
            row(:created_at) { l(invoice.created_at, format: :medium) }
            row(:created_by)
            if invoice.sent_at?
              row(:sent_at) { l(invoice.sent_at, format: :medium) if invoice.sent_at }
              row(:sent_by)
            end
            if invoice.closed?
              row(:closed_at) { l(invoice.closed_at, format: :medium) if invoice.closed_at }
              row(:closed_by)
            elsif invoice.canceled?
              row(:canceled_at) { l invoice.canceled_at, format: :medium }
              row(:canceled_by)
            end
          end
        end

        panel Invoice.human_attribute_name(:amount) do
          attributes_table do
            if invoice.amount_percentage?
              row(:amount_before_percentage, class: "tabular-nums text-right") { cur(invoice.amount_before_percentage) }
              row(:amount_percentage, class: "tabular-nums text-right") { number_to_percentage(invoice.amount_percentage, precision: 1) }
            end
            row(:amount, class: "tabular-nums text-right") { cur(invoice.amount) }
            row(:paid_amount, class: "tabular-nums text-right") { cur(invoice.paid_amount) }
            row(:balance, class: "tabular-nums text-right font-bold") { cur(invoice.balance) }
          end
        end

        if invoice.sepa?
          panel "SEPA" do
            attributes_table do
              row(:iban) { invoice.sepa_metadata["iban"].gsub(/.{4}/, '\0 ') }
              row(Member.human_attribute_name(:sepa_mandate_id)) {
                "#{invoice.sepa_metadata["mandate_id"]} (#{l Date.parse(invoice.sepa_metadata["mandate_signed_on"]), format: :short})"
              }
            end

            if Current.org.bank_connection?
              h4(Invoice.human_attribute_name(:sepa_direct_debit), class: "m-2 mt-4")
              attributes_table do
                row(:sepa_direct_debit_order_id) { invoice.sepa_direct_debit_order_id }
                row(:sepa_direct_debit_order_uploaded_at) { l(invoice.sepa_direct_debit_order_uploaded_at, format: :short) if invoice.sepa_direct_debit_order_uploaded_at? }
                row(:sepa_direct_debit_order_uploaded_by)
              end
              if invoice.sepa_direct_debit_order_uploadable?
                unless invoice.sepa_direct_debit_order_uploaded?
                  div class: "my-4" do
                    button_to upload_sepa_direct_debit_order_invoice_path(invoice),
                      form: { class: "flex justify-center", data: { controller: "disable", disable_with_value: t(".uploading") } },
                      class: "btn btn-sm", data: { confirm: t("active_admin.batch_actions.default_confirmation") } do
                        icon("file-up", class: "size-4 mr-2") + t(".send_sepa_direct_debit_order_to_the_bank")
                      end
                  end

                  days = (invoice.sepa_direct_debit_order_automatic_upload_scheduled_on - Date.today).to_i
                  para t(".sepa_direct_debit_order_will_be_automatically_uploaded_in", count: days), class: "hint"
                end
              elsif !invoice.sent? && invoice.open?
                para t(".invoice_must_be_sent_before_sepa_direct_debit_order_upload"), class: "hint"
              end
            elsif invoice.open?
              div class: "mt-4 mb-2 flex items-center justify-center" do
                link_to sepa_pain_invoice_path(invoice), class: "btn btn-sm", title: Billing::SEPADirectDebit::SCHEMA, data: { turbo: false } do
                  icon("document-arrow-down", class: "size-4 me-1.5") + t(".sepa_pain")
                end
              end
            end
          end
        else
          panel Invoice.human_attribute_name(:overdue_notices_count), count: invoice.overdue_notices_count do
            attributes_table do
              row(:overdue_notice_sent_at) { l invoice.overdue_notice_sent_at if invoice.overdue_notice_sent_at }
            end
          end
        end

        render "active_admin/attachments/panel", attachments: invoice.attachments

        active_admin_comments_for(invoice)
      end
    end
  end

  action_item :new_payment, only: :show, if: -> { authorized?(:create, Payment) } do
    action_link t(".new_payment"), new_payment_path(
      invoice_id: resource.id, amount: [ resource.amount, resource.missing_amount ].min),
      icon: "plus"
  end

  action_item :refund, only: :show, if: -> { resource.can_refund? } do
    shares_number = [ resource.shares_number, resource.member.shares_number ].min
    action_link t(".refund"),
      new_invoice_path(member_id: resource.member_id, shares_number: -shares_number, anchor: "share"),
      icon: "receipt-refund"
  end

  action_item :send_email, only: :show, if: -> { authorized?(:send_email, resource) } do
    action_button t(".send_email"), send_email_invoice_path(resource),
      icon: "paper-airplane"
  end

  action_item :mark_as_sent, only: :show, if: -> { authorized?(:mark_as_sent, resource) } do
    action_button t(".mark_as_sent"), mark_as_sent_invoice_path(resource),
      data: { confirm: t(".mark_as_sent_confirm") },
      icon: "mail-plus"
  end

  action_item :cancel, only: :show, if: -> { authorized?(:cancel, resource) && resource.entity_type != "Shop::Order" } do
    action_button t(".cancel_invoice"), cancel_invoice_path(resource),
      data: { confirm: t(".cancel_invoice_confirm") },
      class: "destructive",
      icon: "circle-off"
  end

  action_item :cancel_and_edit_shop_order, only: :show, if: -> { resource.shop_order_type? && authorized?(:cancel, resource.entity) } do
    action_button t(".cancel_and_edit_shop_order"), cancel_shop_order_path(resource.entity),
      data: { confirm: t(".cancel_action_confirm") },
      icon: "pencil-square"
  end

  action_item :pdf, only: :show, if: -> { resource.processed? } do
    action_link nil, pdf_invoice_path(resource),
      target: "_blank",
      icon: "file-pdf"
  end

  member_action :pdf, method: :get do
    redirect_to rails_blob_path(resource.pdf_file, disposition: "inline")
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

  member_action :sepa_pain, method: :get do
    xml = resource.sepa_direct_debit_pain_xml
    send_data xml, type: "application/xml", filename: "invoice-#{resource.id}-pain.xml"
  end

  member_action :upload_sepa_direct_debit_order, method: :post do
    if resource.upload_sepa_direct_debit_order
      redirect_to resource_path, flash: { notice: t(".flash.notice") }
    else
      redirect_to resource_path, flash: { error: t(".flash.error") }
    end
  end

  collection_action :sepa_pain_all, method: :get do
    invoices = collection.offset(nil).limit(nil).open.sepa.to_a
    sepa = Billing::SEPADirectDebit.new(invoices)
    send_data sepa.xml, type: "application/xml", filename: sepa.filename
  end

  form do |f|
    f.object.errors.attribute_names.each do |attr|
      f.semantic_errors attr
    end

    f.inputs t(".details") do
      f.input :member,
        collection: Member.order_by_name,
        prompt: true,
        input_html: {
          disabled: f.object.entity.is_a?(ActivityParticipation)
        }
      if f.object.entity.is_a?(ActivityParticipation)
        f.input :member_id, as: :hidden
      end
      f.hidden_field :entity_id
      f.hidden_field :entity_type
      f.input :date, as: :date_picker
      unless f.object.persisted?
        f.input :comment, as: :text, input_html: { rows: 4 }
      end
    end
    f.inputs do
      tabs do
        unless f.object.persisted?
          if feature?("activity")
            tab activities_human_name, id: "activity_participation" do
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
              f.input :missing_activity_participations_fiscal_year,
                as: :select,
                prompt: true,
                collection: fiscal_years_collection,
                selected: f.object.missing_activity_participations_fiscal_year.year,
                input_html: { disabled: f.object.entity.is_a?(ActivityParticipation) }
              f.input :missing_activity_participations_count,
                as: :number,
                step: 1,
                input_html: { disabled: f.object.entity.is_a?(ActivityParticipation) }
              f.input :activity_price, as: :number, min: 0, max: 99999.95, step: 0.05, hint: true
            end
          end
          if Current.org.share?
            tab t_invoice_entity_type("Share"), id: "share", hidden: f.object.entity.is_a?(ActivityParticipation) do
              f.input :shares_number, as: :number, step: 1
            end
          end
        end
        tab t_invoice_entity_type("Other"), id: "items", hidden: f.object.entity.is_a?(ActivityParticipation) do
          f.semantic_errors :items
          if Current.org.vat_number?
            f.input :vat_rate, as: :number, min: 0, max: 100, step: 0.01
          end
          f.has_many :items, new_record: t(".has_many_new_invoice_item"), allow_destroy: true do |ff|
            ff.input :description
            ff.input :amount, as: :number, step: 0.01, min: 0, max: 99999.99
          end
        end
      end
    end

    f.inputs Attachment.model_name.human(count: 2) do
      f.para t(".invoice_attachments_html")
      render partial: "active_admin/attachments/form", locals: { f: f }
    end

    f.actions
  end

  permit_params \
    :member_id,
    :entity_id,
    :entity_type,
    :date,
    :comment,
    :missing_activity_participations_count,
    :missing_activity_participations_fiscal_year,
    :activity_price,
    :shares_number,
    :vat_rate,
    items_attributes: %i[id description amount _destroy],
    attachments_attributes: [ :id, :file, :_destroy ]

  before_build do |invoice|
    if params[:activity_participation_id]
      ap = ActivityParticipation.find(params[:activity_participation_id])
      invoice.member = ap.member
      invoice.entity = ap
      invoice.missing_activity_participations_count = ap.participants_count
      invoice.missing_activity_participations_fiscal_year = ap.activity.fiscal_year
    elsif params[:member_id]
      member = Member.find(params[:member_id])
      invoice.member = member
    end
    if params[:shares_number]
      invoice.shares_number ||= params[:shares_number]
    end

    invoice.member_id ||= referer_filter(:member_id)
    invoice.date ||= Date.current
    invoice.missing_activity_participations_fiscal_year ||= Current.fiscal_year
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
    if params.dig(:q, :during_year).present? && params.dig(:q, :during_year).to_i < Current.fy_year
      params[:scope] ||= "all"
    end
  end

  controller do
    include TranslatedCSVFilename
    include ApplicationHelper

    before_action :regenerate_pdf!, only: [ :show, :pdf ]
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
      super(chain).joins(:member).merge(Member.order_by_name)
    end

    def refresh_invoice
      if resource.valid?
        resource.attach_pdf
        Billing::PaymentsRedistributor.redistribute!(resource.member_id)
      end
    end

    def regenerate_pdf!
      return unless Rails.env.development?
      return if resource.processing?
      return if resource.pdf_file.attachment.created_at > 1.hour.ago

      Tempfile.open do |file|
        I18n.with_locale(resource.member.language) do
          pdf = PDF::Invoice.new(resource)
          pdf.render_file(file.path)
          PDF::InvoiceCancellationStamp.stamp!(file.path) if resource.canceled?
        end
        resource.pdf_file.attach io: file, filename: "invoice-#{resource.id}.pdf"
      end
    end
  end

  order_by("members.name") do |clause|
    Member
      .order_by_name(clause.order)
      .order_values
      .join(" ")
  end

  config.sort_order = "date_desc"
end
