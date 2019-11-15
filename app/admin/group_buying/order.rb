ActiveAdmin.register GroupBuying::Order do
  menu parent: :group_buying, priority: 1
  actions :index, :show

  filter :id, as: :numeric
  filter :delivery,
    as: :select,
    collection: -> { GroupBuying::Delivery.order(created_at: :desc) }
  filter :member,
    as: :select,
    collection: -> { Member.joins(:group_buying_orders).order(:name).distinct }
  filter :created_at

  includes :member, :delivery

  index download_links: false do
    column :id, ->(order) { auto_link order, order.id }
    column :created_at, ->(order) { auto_link order, l(order.date) }
    column :delivery, ->(order) { auto_link order.delivery }, sortable: 'delivery_id'
    column :member, ->(order) { auto_link order.member }
    column :amount, ->(order) { number_to_currency(order.amount) }
    actions
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
          row(:created_at) { l(order.created_at, date_format: :long) }
          row(:delivery) { auto_link order.delivery }
          row(:member) { auto_link order.member }
          row(:amount) { number_to_currency(order.amount) }
        end
        active_admin_comments
      end
    end
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
