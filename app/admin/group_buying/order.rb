ActiveAdmin.register GroupBuying::Order do
  menu parent: :group_buying, priority: 1
  actions :index, :show

  breadcrumb do
    if params['action'] == 'index'
      [t('active_admin.menu.group_buying')]
    else
      [
        t('active_admin.menu.group_buying'),
        link_to(GroupBuying::Delivery.model_name.human(count: 2), group_buying_deliveries_path),
        auto_link(group_buying_order.delivery),
        link_to(
          GroupBuying::Order.model_name.human(count: 2),
          group_buying_orders_path(q: { delivery_id_eq: group_buying_order.delivery_id }, scope: :all))
      ]
    end
  end

  scope :all_without_canceled, default: true
  scope :open
  scope :closed
  scope :canceled

  filter :id, as: :numeric
  filter :delivery,
    as: :select,
    collection: -> { GroupBuying::Delivery.order(created_at: :desc) }
  filter :member,
    as: :select,
    collection: -> { Member.joins(:group_buying_orders).order(:name).distinct }
  filter :created_at

  includes :member, :delivery, invoice: { pdf_file_attachment: :blob }
  index do
    column :id, ->(order) { auto_link order, order.id }
    column :created_at, ->(order) { l(order.date, format: :number) }
    column :delivery, ->(order) { auto_link order.delivery, order.delivery.title  }, sortable: 'delivery_id'
    column :member, sortable: 'members.name'
    column :amount, ->(order) { number_to_currency(order.amount) }
    column :state, ->(order) { status_tag order.state_i18n_name, class: order.state }
    actions defaults: true do |order|
      link_to 'PDF', rails_blob_path(order.invoice.pdf_file, disposition: 'attachment'), class: 'pdf_link'
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
    column :amount
    column(:balance) { |o| o.invoice.balance }
    column(:missing_amount) { |o| o.invoice.missing_amount }
    column :state, &:state_i18n_name
  end

  sidebar I18n.t('active_admin.sidebars.total'), only: :index do
    all = collection.unscope(:includes).eager_load(:invoice).limit(nil)

    if params[:scope].in? ['all_without_canceled', 'open', nil]
      div class: 'total' do
        span t('billing.scope.missing')
        span number_to_currency(all.sum('invoices.amount - invoices.balance')), style: 'float: right'
      end
      div class: 'total' do
        span t('billing.scope.paid')
        span number_to_currency(all.sum('invoices.balance')), style: 'float: right;'
      end
      div class: 'totals' do
        span t('active_admin.sidebars.amount')
        span number_to_currency(all.sum(:amount)), style: 'float: right; font-weight: bold;'
      end
    else
      div do
        span t('active_admin.sidebars.amount')
        span number_to_currency(all.sum(:amount)), style: 'float: right; font-weight: bold;'
      end
    end
  end

  show do |order|
    columns do
      column do
        panel "#{order.items_count} #{GroupBuying::Product.model_name.human(count: order.items_count)}" do
          table_for order.items.includes(:product), class: 'table-group_buying_orders' do
            column(:product) { |i| auto_link i.product }
            column(:price) { |i| number_to_currency(i.price) }
            column(:quantity)
            column(:amount) { |i| number_to_currency(i.amount) }
          end
        end
      end
      column do
        attributes_table do
          row :id
          row(:delivery) { auto_link order.delivery, order.delivery.title }
          row(:member) { auto_link order.member }
          row(:invoice) { auto_link order.invoice }
          row(:state) { status_tag order.state_i18n_name, class: order.state }
          row(:created_at) { l(order.created_at, date_format: :long) }
        end

        attributes_table title: Invoice.human_attribute_name(:amount) do
          row(:amount) { number_to_currency(order.amount) }
          row(:balance) { number_to_currency(order.invoice.balance) }
          row(:missing_amount) { number_to_currency(order.invoice.missing_amount) }
        end

        active_admin_comments
      end
    end
  end

  action_item :pdf, only: :show do
    link_to 'PDF', rails_blob_path(resource.invoice.pdf_file, disposition: 'attachment')
  end

  action_item :new_payment, only: :show, if: -> { authorized?(:create, Payment) } do
    link_to t('.new_payment'), new_payment_path(
      invoice_id: resource.invoice.id, amount: [resource.invoice.amount, resource.invoice.missing_amount].min)
  end

  action_item :cancel, only: :show, if: -> { authorized?(:cancel, resource) } do
    link_to t('.cancel_invoice'), cancel_group_buying_order_path(resource), method: :post, data: { confirm: t('.link_confirm') }
  end

  member_action :cancel, method: :post do
    resource.invoice.cancel!
    redirect_to resource_path, notice: t('.flash.notice')
  end

  controller do
    include TranslatedCSVFilename

    before_action delivery: :index do
      if params[:q].blank? && next_delivery = GroupBuying::Delivery.next
        params[:q] = { delivery_id_eq: next_delivery.id }
      end
    end
  end

  config.sort_order = 'created_at_desc'
end
