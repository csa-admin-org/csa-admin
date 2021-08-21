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
          shop_orders_path(q: { delivery_id_eq: shop_order.delivery_id }, scope: :all))
        if params['action'].in? %W[edit]
          links << auto_link(shop_order, shop_order.id)
        end
      end
      links
    end
  end

  scope :all
  scope :pending, default: true
  scope :invoiced

  filter :id, as: :numeric
  filter :delivery,
    as: :select,
    collection: -> { Delivery.joins(:shop_orders).distinct }
  filter :member,
    as: :select,
    collection: -> { Member.joins(:shop_orders).order(:name).distinct }
  filter :amount
  filter :created_at

  includes :member, :delivery, invoice: { pdf_file_attachment: :blob }
  index do
    column :id, ->(order) { auto_link order, order.id }
    column :created_at, ->(order) { l(order.date, format: :number) }
    column :delivery, ->(order) { auto_link order.delivery, order.delivery.display_name  }, sortable: 'delivery_id'
    column :member, sortable: 'members.name'
    column :amount, ->(order) { cur(order.amount) }
    column :state, ->(order) { status_tag order.state_i18n_name, class: order.state }
    actions defaults: true, class: 'col-actions-3'do |order|
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

  sidebar I18n.t('active_admin.sidebars.total'), only: :index do
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

  show do |order|
    columns do
      column do
        panel "#{order.items.size} #{GroupBuying::Product.model_name.human(count: order.items.size)}" do
          table_for order.items.includes(:product), class: 'table-shop_orders' do
            column(:product) { |i| auto_link i.product }
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
          row(:created_at) { l(order.created_at, date_format: :long) }
          row(:updated_at) { l(order.updated_at, date_format: :long) }
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
    if f.object.errors[:items].present?
      ul class: 'errors' do
        f.object.errors.full_messages.each do |msg|
          li msg
        end
      end
    end
    products = Shop::Product.available
    f.inputs t('.details') do
      f.input :member, collection: Member.reorder(:name), prompt: true
      f.input :delivery, prompt: true
      f.has_many :items, allow_destroy: true do |ff|
        ff.input :product, collection: products_collection(products), prompt: true,
          input_html: { class: 'js-reset_price js-update_product_variant_options' }
        ff.input :product_variant,
          collection: product_variants_collection(products, ff.object.product_id),
          input_html: { class: 'js-reset_price hide-disabled-options', disabled: ff.object.product_variant_id.blank? }
        ff.input :item_price, hint: true, required: false
        ff.input :quantity, as: :number, step: 1, min: 1
      end
    end
    f.actions
  end

  permit_params(
    :member_id,
    :delivery_id,
    items_attributes: [
      :id,
      :product_id,
      :product_variant_id,
      :item_price,
      :quantity,
      :_destroy
    ])

  action_item :invoice, only: :show, if: -> { resource.can_invoice? } do
    link_to t('.invoice_action'), invoice_shop_order_path(resource), method: :post
  end

  member_action :invoice, method: :post, only: :show, if: -> { resource.can_invoice? } do
    resource.invoice!
    redirect_to resource_path, notice: t('.flash.notice')
  end

  action_item :cancel, only: :show, if: -> { resource.can_cancel? } do
    link_to t('.cancel_action'), cancel_shop_order_path(resource),
      method: :post,
      data: { confirm: t('.cancel_action_confirm') }
  end

  member_action :cancel, method: :post, only: :show, if: -> { resource.can_cancel? } do
    resource.cancel!
    redirect_to edit_shop_order_path(resource), notice: t('.flash.notice')
  end

  action_item :pdf, only: :show, if: -> { resource.invoice&.processed? } do
    link_to_invoice_pdf(resource.invoice)
  end

  action_item :new_payment, only: :show, if: -> { authorized?(:create, Payment) && resource.invoice } do
    link_to t('.new_payment'), new_payment_path(
      invoice_id: resource.invoice.id, amount: [resource.invoice.amount, resource.invoice.missing_amount].min)
  end

  before_build do |order|
    order.member_id ||= referer_filter_member_id
    order.delivery ||= Delivery.next
  end

  controller do
    include TranslatedCSVFilename
    include ApplicationHelper
    include ShopHelper

    before_action delivery: :index do
      if params[:q].blank? && next_delivery = Delivery.next
        params[:q] = { delivery_id_eq: next_delivery.id }
      end
    end

    before_create do |order|
      order.state = Shop::Order::PENDING_STATE
    end
  end

  config.sort_order = 'created_at_desc'
end
