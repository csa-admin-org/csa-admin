ActiveAdmin.register GroupBuying::Order do
  menu parent: :group_buying, priority: 1
  actions :index, :show

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
    column :delivery, ->(order) { auto_link order.delivery }, sortable: 'delivery_id'
    column :member, ->(order) { auto_link order.member }
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
    column :state, &:state_i18n_name
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
          row(:delivery) { auto_link order.delivery }
          row(:member) { auto_link order.member }
          row(:invoice) { auto_link order.invoice }
          row(:state) { status_tag order.state_i18n_name, class: order.state }
          row(:created_at) { l(order.created_at, date_format: :long) }
          row(:amount) { number_to_currency(order.amount) }
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
    link_to t('.cancel_invoice'), cancel_invoice_path(resource.invoice), method: :post, data: { confirm: t('.link_confirm') }
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
