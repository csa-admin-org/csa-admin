ActiveAdmin.register Shop::Order do
  menu parent: :shop, priority: 1

  breadcrumb do
    if params['action'] == 'index'
      [t('active_admin.menu.shop')]
    else
      links = [
        t('active_admin.menu.shop'),
        link_to(Shop::Order.model_name.human(count: 2), shop_orders_path)
      ]
      if params['action'].in? %W[show edit]
        links << link_to(
          shop_order.delivery.display_name,
          shop_orders_path(q: { _delivery_gid_eq: shop_order.delivery_gid }, scope: :all_without_cart))
        if params['action'].in? %W[edit]
          links << auto_link(shop_order, shop_order.id)
        end
      end
      links
    end
  end

  scope :all_without_cart
  scope :pending, default: true
  scope :invoiced

  filter :id, as: :numeric
  filter :_delivery_gid,
    as: :select,
    collection: -> { shop_deliveries_collection },
    label: -> { Delivery.model_name.human }
  filter :member,
    as: :select,
    collection: -> {
      Member
        .joins(:shop_orders).where.not(shop_orders: { state: :cart })
        .order(:name)
        .distinct
    }
  filter :amount
  filter :created_at

  includes :member, :delivery, invoice: { pdf_file_attachment: :blob }
  index do
    selectable_column if params[:scope].in?([nil, 'pending'])
    column :id, ->(order) { auto_link order, order.id }
    column :created_at, ->(order) { l(order.date, format: :number) }
    column :delivery, ->(order) { auto_link order.delivery, order.delivery.display_name  }, sortable: 'delivery_id'
    column :member, sortable: 'members.name'
    column :amount, ->(order) { cur(order.amount) }
    column :state, ->(order) { status_tag order.state_i18n_name, class: order.state }
    actions defaults: true, class: 'col-actions-3' do |order|
      link_to_invoice_pdf(order.invoice)
    end
  end

  csv do
    column :id
    column :member_id
    column(:name) { |o| o.member.name }
    column(:emails) { |o| o.member.emails_array.join(', ') }
    column :delivery_id
    column(:delivery_date) { |o| o.delivery.date }
    column :created_at
    column :state, &:state_i18n_name
    column :amount
    column(:invoice_id) { |o| o.invoice&.id }
    column(:paid_amount) { |o| o.invoice&.paid_amount }
    column(:balance) { |o| o.invoice&.balance }
  end

  sidebar_shop_admin_only_warning

  sidebar t('active_admin.sidebars.total'), only: :index do
    all = collection.unscope(:includes).eager_load(:invoice).limit(nil)
    div class: 'content' do
      if params[:scope].in? ['invoiced', nil]
        div class: 'total' do
          span t('billing.scope.paid')
          span cur(all.sum('invoices.paid_amount')), style: 'float: right;'
        end
        div class: 'total' do
          span t('billing.scope.missing')
          span cur(all.sum('invoices.amount - invoices.paid_amount')), style: 'float: right'
        end
        div class: 'totals' do
          span t('active_admin.sidebars.amount')
          span cur(all.sum(:amount)), style: 'float: right; font-weight: bold;'
        end
      else
        div do
          span t('active_admin.sidebars.amount')
          span cur(all.sum(:amount)), style: 'float: right; font-weight: bold;'
        end
      end
    end
  end

  sidebar t('active_admin.sidebars.shop_status'), if: -> { params.dig(:q, :delivery_id_eq) }, only: :index do
    div class: 'content' do
      delivery = Delivery.find(params[:q][:delivery_id_eq])
      if delivery == Delivery.shop_open.next
        if delivery.shop_open?
          span t('active_admin.sidebars.shop_open_until_html', date: l(delivery.date, format: :long), end_date: l(delivery.shop_closing_at, format: :long))
        else
          span t('active_admin.sidebars.shop_closed_html', date: l(delivery.date, format: :long))
        end
      elsif delivery.date.past?
        span t('active_admin.sidebars.shop_closed_html', date: l(delivery.date, format: :long))
      else
        span t('active_admin.sidebars.shop_not_open_yet_html', date: l(delivery.date, format: :long))
      end
    end
  end

  sidebar_handbook_link('shop#commandes')

  show do |order|
    columns do
      column do
        panel "#{order.items.size} #{GroupBuying::Product.model_name.human(count: order.items.size)}" do
          table_for order.items.includes(:product, :product_variant), class: 'table-shop_orders' do
            column(:product) { |i| link_to "#{i.product.name}, #{i.product_variant.name}", [:edit, i.product] }
            column(:item_price) { |i| cur(i.item_price) }
            column(:quantity)
            column(:amount) { |i| cur(i.amount) }
          end
        end
      end
      column do
        attributes_table do
          row :id
          row(:delivery) { auto_link order.delivery, order.delivery.display_name }
          row(:member) { auto_link order.member }
          row(:state) { status_tag order.state_i18n_name, class: order.state }
          row(:weight) { kg(order.weight_in_kg) }
          row(:created_at) { l(order.created_at, format: :long) }
          row(:updated_at) { l(order.updated_at, format: :long) }
        end

        attributes_table title: t('billing.title') do
          row(:amount) { cur(order.amount) }
          if order.invoice
            row(:invoice) { auto_link order.invoice, order.invoice.id }
            row(:state) { status_tag order.invoice.state_i18n_name, class: order.invoice.state }
            row(:paid_amount) { cur(order.invoice.paid_amount) }
            row(:balance) { cur(order.invoice.balance) }
          end
        end

        active_admin_comments
      end
    end
  end

  form do |f|
    f.semantic_errors :base
    f.semantic_errors :amount
    f.inputs t('.details') do
      f.input :member, collection: Member.reorder(:name), prompt: true
      f.input :delivery_gid,
        label: Delivery.model_name.human,
        prompt: true,
        collection: shop_deliveries_collection
      f.has_many :items, allow_destroy: true do |ff|
        ff.inputs class: 'blank', 'data-controller' => 'form-reset form-select-options-filter', 'data-form-select-options-filter-attribute-value' => 'data-product-id' do
          ff.input :product,
            collection: products_collection,
            prompt: true,
            input_html: {
              data: { action: 'form-reset#reset form-select-options-filter#filter' }
            }
          ff.input :product_variant,
            collection: product_variants_collection(ff.object.product_id),
            input_html: {
              class: 'hide-disabled-options',
              disabled: ff.object.product_variant_id.blank?,
              data: {
                action: 'form-reset#reset',
                form_select_options_filter_target: 'select'
              }
            }
          ff.input :quantity, as: :number, step: 1, min: 1
          ff.input :item_price,
            hint: true,
            required: false,
            input_html: { data: { form_reset_target: 'input' } }
        end
      end
    end
    f.actions
  end

  permit_params(
    :member_id,
    :delivery_gid,
    items_attributes: [
      :id,
      :product_id,
      :product_variant_id,
      :item_price,
      :quantity,
      :_destroy
    ])

  action_item :invoice, only: :show, if: -> { resource.can_invoice? } do
    button_to t('.invoice_action'), invoice_shop_order_path(resource),
      form: { data: { controller: 'disable', disable_with_value: t('formtastic.processing') } }
  end

  member_action :invoice, method: :post, only: :show, if: -> { resource.can_invoice? } do
    resource.admin = current_admin
    resource.invoice!
    redirect_to resource_path, notice: t('.flash.notice')
  end

  action_item :cancel, only: :show, if: -> { resource.can_cancel? } do
    button_to t('.cancel_action'), cancel_shop_order_path(resource),
      form: { data: { controller: 'disable', disable_with_value: t('formtastic.processing') } },
      data: { confirm: t('.cancel_action_confirm') }
  end

  member_action :cancel, method: :post, only: :show, if: -> { resource.can_cancel? } do
    resource.admin = current_admin
    resource.cancel!
    redirect_to edit_shop_order_path(resource), notice: t('.flash.notice')
  end

  action_item :new_payment, only: :show, if: -> { authorized?(:create, Payment) && resource.invoice } do
    link_to t('.new_payment'), new_payment_path(
      invoice_id: resource.invoice.id, amount: [resource.invoice.amount, resource.invoice.missing_amount].min)
  end

  action_item :pdf, only: :show, if: -> { resource.invoice&.processed? } do
    link_to_invoice_pdf(resource.invoice, title: t('.invoice_pdf'))
  end

  action_item :delivery_pdf, only: :show do
    link_to t('.delivery_order_pdf'), delivery_shop_orders_path(delivery_gid: resource.delivery_gid, shop_order_id: resource.id, format: :pdf), target: '_blank'
  end

  action_item :order_items_csv, only: :index, if: -> { params[:q]&.key?(:delivery_id_eq) } do
    delivery_id = params.dig(:q, :delivery_id_eq)
    link_to t('.order_items_csv'), shop_order_items_path(q: { delivery_id_eq: delivery_id }, format: :csv)
  end

  action_item :delivery_pdf, only: :index, if: -> { params[:q]&.key?(:_delivery_gid_eq) } do
    delivery_gid = params.dig(:q, :_delivery_gid_eq)
    link_to t('.delivery_orders_pdf'), delivery_shop_orders_path(delivery_gid: delivery_gid, format: :pdf), target: '_blank'
  end

  action_item :delivery_xlsx, only: :index, if: -> { params[:q]&.key?(:_delivery_gid_eq) } do
    delivery_gid = params.dig(:q, :_delivery_gid_eq)
    link_to 'XLSX', delivery_shop_orders_path(delivery_gid: delivery_gid, format: :xlsx), target: '_blank'
  end

  batch_action :invoice, if: ->(attr) { params[:scope].in?([nil, 'pending']) } do |selection|
    Shop::Order.where(id: selection).find_each do |order|
      order.admin = current_admin
      order.invoice!
    end
    redirect_back fallback_location: collection_path
  end

  collection_action :delivery, method: :get, if: -> { params[:delivery_gid] } do
    delivery = GlobalID::Locator.locate(params[:delivery_gid])
    case params[:format]
    when 'pdf'
      order = Shop::Order.find(params[:shop_order_id]) if params[:shop_order_id]
      pdf = PDF::Shop::Delivery.new(delivery, order: order)
      send_data pdf.render,
        content_type: pdf.content_type,
        filename: pdf.filename,
        disposition: 'inline'
    when 'xlsx'
      producer = Shop::Producer.find(params[:producer_id]) if params[:producer_id]
      xlsx = XLSX::Shop::Delivery.new(delivery, producer)
      send_data xlsx.data,
        content_type: xlsx.content_type,
        filename: xlsx.filename
    end
  end

  before_action only: :index do
    if params.except(:subdomain, :controller, :action).empty? &&
        params[:q].blank? &&
        next_delivery = Delivery.shop_open.next
      redirect_to q: { _delivery_gid_eq: next_delivery.gid }, utf8: '✓'
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
      order.state = Shop::Order::PENDING_STATE
    end
  end

  config.sort_order = 'created_at_desc'
  config.batch_actions = true
end
