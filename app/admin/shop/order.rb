# frozen_string_literal: true

ActiveAdmin.register Shop::Order do
  menu \
   parent: :navshop,
   priority: 1,
   url: -> { smart_shop_orders_path }

  breadcrumb do
    links = [ t("active_admin.menu.shop") ]

    if params[:action] == "new"
      links << link_to(Shop::Order.model_name.human(count: 2), smart_shop_orders_path)
    elsif params[:action] != "index"
      links << link_to(
        [ Shop::Order.model_name.human(count: 2), resource.delivery.display_name ].join(" – ").html_safe,
        shop_orders_path(q: { _delivery_gid_eq: resource.delivery_gid }))
      if params["action"] == "edit"
        links << auto_link(resource, resource.id)
      end
    end
    links
  end

  scope :all_without_cart, default: true
  scope :pending, group: :state
  scope :invoiced, group: :state

  filter :_delivery_gid,
    as: :select,
    collection: -> { shop_deliveries_collection(used: true) },
    label: -> { Delivery.model_name.human }
  filter :during_year,
    as: :select,
    collection: -> { fiscal_years_collection }
  filter :created_at
  filter :id, as: :numeric
  filter :member,
    as: :select,
    collection: -> { members_collection(collection) }
  filter :depot, as: :select, collection: -> { admin_depots_collection }
  filter :amount

  includes :member, :depot, invoice: { pdf_file_attachment: :blob }
  index download_links: [ :csv, :xlsx ], title: -> {
    title = Shop::Order.model_name.human(count: 2)
    if params.dig(:q, :_delivery_gid_eq).present?
        && delivery = GlobalID::Locator.locate(params.dig(:q, :_delivery_gid_eq))
      title += " – #{delivery.display_name}"
    end
    title
  } do
    selectable_column(class: "w-px") if params[:scope].in?([ nil, "pending" ])
    column :id
    column :created_at, ->(order) { l(order.date, format: :number) }, class: "text-right"
    column :member, sortable: "members.name"
    if params.dig(:q, :_delivery_gid_eq).present?
      column :depot, sortable: "depots.name"
    else
      column :delivery, ->(order) { auto_link order.delivery, order.delivery.display_name  }, sortable: "delivery_id"
    end
    column :amount, ->(order) { cur(order.amount) }, class: "text-right"
    column :state, ->(order) { status_tag order.state, label: order.state_i18n_name }, class: "text-right"
    actions do |order|
      link_to_invoice_pdf(order.invoice)
    end
  end

  csv do
    column :id
    column(:member_id) { |o| o.member&.display_id }
    column(:name) { |o| o.member.name }
    column(:emails) { |o| o.member.emails_array.join(", ") }
    column(:delivery) { |o| strip_tags(o.delivery.display_name) }
    column(:delivery_date) { |o| o.delivery.date }
    column(:depot) { |o| o.depot&.name }
    column :created_at
    column :state, &:state_i18n_name
    column :amount
    column(:invoice_id) { |o| o.invoice&.id }
    column(:paid_amount) { |o| o.invoice&.paid_amount }
    column(:balance) { |o| o.invoice&.balance }
  end

  sidebar_shop_admin_only_warning

  sidebar :total, only: :index do
    side_panel t(".total") do
      all = collection.unscope(:includes).eager_load(:invoice).offset(nil).limit(nil)
      if params[:scope].in? [ "invoiced", nil ]
        div number_line(t("billing.scope.paid"), cur(all.sum("invoices.paid_amount")), bold: false)
        div number_line(t("billing.scope.missing"), cur(all.sum("invoices.amount - invoices.paid_amount")), bold: false)
        div number_line(t(".amount"), cur(all.sum(:amount)), border_top: true)
      else
        div number_line(t(".amount"), cur(all.sum(:amount)))
      end
    end
  end

  sidebar :shop_status, if: -> { params.dig(:q, :_delivery_gid_eq).present? }, only: :index do
    side_panel t(".shop_status") do
      delivery = GlobalID::Locator.locate(params[:q][:_delivery_gid_eq])
      if delivery == Delivery.shop_open.next
        if delivery.shop_open?
          span t("active_admin.shared.sidebar_section.shop_open_until_html", date: l(delivery.date, format: :long), end_date: l(delivery.shop_closing_at, format: :medium))
        else
          span t("active_admin.shared.sidebar_section.shop_closed_html", date: l(delivery.date, format: :long))
        end
      elsif delivery.date.past?
        span t("active_admin.shared.sidebar_section.shop_closed_html", date: l(delivery.date, format: :long))
      else
        span t("active_admin.shared.sidebar_section.shop_not_open_yet_html", date: l(delivery.date, format: :long))
      end
    end
  end

  sidebar :billing, if: -> { params.dig(:q, :_delivery_gid_eq).present? }, only: :index do
    side_panel t(".billing"), action: handbook_icon_link("shop", anchor: "facturation") do
      if delay = Current.org.shop_order_automatic_invoicing_delay_in_days
        delivery = GlobalID::Locator.locate(params[:q][:_delivery_gid_eq])
        date = delivery.date + delay.days
        span t("shop.orders_automatic_invoicing", date: l(date, format: :long))
      else
        span t("shop.orders_manual_invoicing")
      end
    end
  end

  sidebar_handbook_link("shop#orders")

  show do |order|
    columns do
      column do
        panel Shop::Product.model_name.human(count: 2), count: order.items.size do
          table_for order.items.includes(:product, :product_variant), class: "table-auto" do
            column(:product) { |i| auto_link i.product, "#{i.product.name}, #{i.product_variant.name}", aria: { label: "show" } }
            column(:item_price, class: "text-right") { |i| cur(i.item_price) }
            column(:quantity, class: "text-right")
            column(:amount, class: "text-right") { |i| cur(i.amount) }
          end
        end
      end
      column do
        panel t(".details") do
          attributes_table do
            row :id
            row(:member)
            row(:delivery) { auto_link order.delivery, order.delivery.display_name }
            row(:depot)
            row(:weight) { kg(order.weight_in_kg) }
            row(:created_at) { l(order.created_at, format: :medium) }
            row(:updated_at) { l(order.updated_at, format: :medium) }
          end
        end

        panel t("billing.title") do
          attributes_table do
            if order.amount_percentage?
              row(:amount_before_percentage) { cur(order.amount_before_percentage) }
              row(:amount_percentage) { number_to_percentage(order.amount_percentage, precision: 1) }
            end
            row(:amount) { cur(order.amount) }
            if order.invoice
              row(:invoice) { auto_link order.invoice, order.invoice.id }
              row(:state) { status_tag order.invoice.state, label: order.invoice.state_i18n_name }
              row(:paid_amount) { ccur(order.invoice, :paid_amount) }
              row(:balance) { ccur(order.invoice, :balance) }
            end
          end
        end

        render "active_admin/attachments/panel", attachments: order.attachments


        active_admin_comments_for(order)
      end
    end
  end

  form do |f|
    f.semantic_errors :base
    f.semantic_errors :amount

    f.inputs t(".details") do
      f.input :member, collection: members_collection, prompt: true
      f.input :delivery_gid,
        label: Delivery.model_name.human,
        prompt: true,
        collection: shop_deliveries_collection
      unless f.object.new_record?
        f.input :depot,
          prompt: true,
          collection: admin_depots_collection
      end
      f.input :amount_percentage,
        step: 0.1, min: -100, max: 200,
        hint: I18n.t("formtastic.hints.shop/order.amount_percentage")
      f.has_many :items, allow_destroy: true, data: { controller: "form-reset form-select-options-filter", form_select_options_filter_attribute_value: "data-product-id" } do |ff|
        ff.input :product,
        collection: products_collection,
        prompt: true,
        input_html: {
          data: { action: "form-reset#reset form-select-options-filter#filter" }
        }
        ff.input :product_variant,
        collection: product_variants_collection(ff.object.product_id),
        input_html: {
          class: "hide-disabled-options",
            disabled: ff.object.product_variant_id.blank?,
            data: {
              action: "form-reset#reset",
              form_select_options_filter_target: "select"
            }
          }
          ff.input :quantity, as: :number, step: 1, min: 1
          ff.input :item_price,
          hint: true,
          required: false,
          input_html: { data: { form_reset_target: "input" } }
      end
      f.semantic_errors :items
    end

    f.inputs Attachment.model_name.human(count: 2) do
      f.para t(".invoice_attachments_html")
      render partial: "active_admin/attachments/form", locals: { f: f }
    end

    f.actions do
      f.action :submit, as: :input
      cancel_link shop_orders_path(q: { _delivery_gid_eq: f.object.delivery_gid })
    end
  end

  permit_params(
    :member_id,
    :delivery_gid,
    :depot_id,
    :amount_percentage,
    attachments_attributes: [ :id, :file, :_destroy ],
    items_attributes: [
      :id,
      :product_id,
      :product_variant_id,
      :item_price,
      :quantity,
      :_destroy
    ])

  action_item :cancel, only: :show, if: -> { resource.can_cancel? } do
    action_button t(".cancel_action"), cancel_shop_order_path(resource),
      data: { confirm: t(".cancel_action_confirm") },
      icon: "pencil-square"
  end

  member_action :cancel, method: :post, only: :show, if: -> { resource.can_cancel? } do
    resource.admin = current_admin
    resource.cancel!
    redirect_to edit_shop_order_path(resource), notice: t(".flash.notice")
  end

  action_item :new_payment, only: :show, if: -> { authorized?(:create, Payment) && resource.invoice } do
    action_link t(".new_payment"), new_payment_path(
      invoice_id: resource.invoice.id, amount: [ resource.invoice.amount, resource.invoice.missing_amount ].min),
      icon: "plus"
  end

  action_item :pdf, only: :show, if: -> { resource.invoice&.processed? } do
    action_link Invoice.model_name.human, pdf_invoice_path(resource.invoice),
      target: "_blank",
      icon: "file-pdf"
  end

  action_item :delivery_pdf, only: :show do
    action_link t(".delivery_order"), delivery_shop_orders_path(delivery_gid: resource.delivery_gid, shop_order_id: resource.id, format: :pdf),
      target: "_blank",
      icon: "file-pdf"
  end

  action_item :invoice, class: "left-margin", only: :show, if: -> { resource.can_invoice? && Current.org.iban? } do
    action_button t(".invoice_action"), invoice_shop_order_path(resource),
      icon: "banknotes"
  end

  action_item :invoice_disabled, class: "left-margin", only: :show, if: -> { resource.can_invoice? && !Current.org.iban? } do
    action_button t(".invoice_action"),
      disabled: true,
      disabled_tooltip: t(".invoice_disabled_reason", iban_type: Current.org.iban_type_name),
      icon: "banknotes"
  end

  member_action :invoice, method: :post, only: :show, if: -> { resource.can_invoice? } do
    resource.admin = current_admin
    resource.invoice!
    redirect_to resource_path, notice: t(".flash.notice")
  end

  action_item :delivery_pdf, only: :index, if: -> { params.dig(:q, :_delivery_gid_eq).present? } do
    delivery_gid = params.dig(:q, :_delivery_gid_eq)
    depot_id = params.dig(:q, :depot_id_eq)
    action_link nil, delivery_shop_orders_path(delivery_gid: delivery_gid, depot_id: depot_id, format: :pdf),
      icon: "file-pdf",
      target: "_blank",
      title: t(".delivery_orders")
  end

  action_item :order_items_xlsx, only: :index do
    permitted_params = params.permit(:scope, q: {}).to_h
    action_link nil, shop_orders_path(**permitted_params, format: :xlsx),
      icon: "file-xlsx",
      target: "_blank"
  end

  batch_action :invoice, if: ->(attr) { Current.org.iban? && params[:scope].in?([ nil, "pending" ]) }, confirm: true do |selection|
    Shop::Order.where(id: selection).find_each do |order|
      order.admin = current_admin
      order.invoice! if order.can_invoice?
    end
    redirect_back fallback_location: collection_path
  end

  collection_action :delivery, method: :get, if: -> { params[:delivery_gid].present? } do
    delivery = GlobalID::Locator.locate(params[:delivery_gid])
    raise ActiveRecord::RecordNotFound unless delivery

    depot = Depot.find(params[:depot_id]) if params[:depot_id].present?
    order = Shop::Order.find(params[:shop_order_id]) if params[:shop_order_id].present?
    pdf = PDF::Shop::Delivery.new(delivery, order: order, depot: depot)
    send_data pdf.render,
      content_type: pdf.content_type,
      filename: pdf.filename,
      disposition: "inline"
  end
  before_action only: :index do
    if params.dig(:q, :during_year).present? && params.dig(:q, :during_year).to_i < Current.fy_year
      params[:scope] ||= "all"
    end
  end

  before_build do |order|
    order.member_id ||= referer_filter(:member_id)
    order.delivery_gid ||= referer_filter(:_delivery_gid)
    order.delivery ||= Delivery.next
    order.admin = current_admin
  end

  before_update do |order|
    order.admin = current_admin
  end

  controller do
    include TranslatedCSVFilename
    include ApplicationHelper
    include ShopHelper

    before_create do |order|
      # Clear stale cart order
      cart_order = Shop::Order.cart.find_by(member_id: order.member_id, delivery_id: order.delivery_id)
      if cart_order && (!cart_order.can_member_update? || cart_order.empty?)
        cart_order.destroy
      end
    end

    after_create do |order|
      order.confirm! if order.valid?
    end

    def find_resource
      scoped_collection
        .where(id: params[:id])
        .includes(items: [ :product, :product_variant ])
        .first!
    end

    def apply_sorting(chain)
      super(chain).joins(:member).merge(Member.order_by_name)
    end

    # Skip pagination when downloading a xlsx file
    def apply_pagination(chain)
      return chain if params["format"] == "xlsx"

      super
    end

    def index
      super do |format|
        format.xlsx do
          xlsx = XLSX::Shop::OrderItem.new(collection)
          send_data xlsx.data,
            content_type: xlsx.content_type,
            filename: xlsx.filename
        end
      end
    end
  end

  order_by("members.name") do |clause|
    Member
      .order_by_name(clause.order)
      .order_values
      .join(" ")
  end

  order_by("depots.name") do |clause|
    Depot
      .reorder_by_name(clause.order)
      .order_values
      .join(" ")
  end

  config.sort_order = "created_at_desc"
  config.batch_actions = true
end
