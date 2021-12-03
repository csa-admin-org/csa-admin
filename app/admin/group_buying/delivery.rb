ActiveAdmin.register GroupBuying::Delivery do
  menu parent: :group_buying, priority: 2

  breadcrumb do
    if params['action'] == 'index'
      [t('active_admin.menu.group_buying')]
    else
      links = [
        t('active_admin.menu.group_buying'),
        link_to(GroupBuying::Delivery.model_name.human(count: 2), group_buying_deliveries_path)
      ]
      if params['action'].in? %W[edit]
        links << auto_link(group_buying_delivery)
      end
      links
    end
  end

  scope :all
  scope :coming, default: true
  scope :past

  filter :date
  filter :depot,
    as: :select,
    collection: -> { Depot.pluck(:name, :id) }
  filter :during_year,
    as: :select,
    collection: -> { fiscal_years_collection }

  includes :orders, :orders_without_canceled

  # Workaround for ActionController::UnknownFormat (xlsx download)
  # https://github.com/activeadmin/activeadmin/issues/4945#issuecomment-302729459
  index download_links: -> { params[:action] == 'show' ? [:xlsx] : false } do
    column '#', ->(delivery) { auto_link delivery, delivery.id }
    column :date, ->(delivery) { auto_link delivery, l(delivery.date) }
    column :orderable_until, ->(delivery) { auto_link delivery, l(delivery.orderable_until) }
    column :orders, ->(delivery) {
      link_to(delivery.orders_without_canceled.size, group_buying_orders_path(q: { delivery_id_eq: delivery.id }))
    }
    actions defaults: true, class: 'col-actions-4' do |delivery|
      link_to('XLSX', group_buying_delivery_path(delivery, format: :xlsx), class: 'xlsx_link')
    end
  end

  show do |delivery|
    columns do
      column do
        all = GroupBuying::DeliveryTotal.all_by_producer(delivery)
        if all.empty?
          panel '' do
            em t('.no_orders')
          end
        else
          all.each do |producer, items|
            xlsx_link = "<span class='link'>#{link_to('XLSX', group_buying_delivery_path(delivery, format: :xlsx, producer_id: producer.id), class: 'xlsx_link')}</span>"
            panel (producer.name + xlsx_link).html_safe do
              table_for items, class: 'totals table-group_buying_orders', i18n: GroupBuying::OrderItem do
                column(:product) { |i| auto_link i.product }
                column(:quantity)
                column(:amount) { |i| cur(i.amount) }
              end
            end
          end
        end
      end
      column do
        attributes_table do
          row :id
          row(:date) { l(delivery.date, date_format: :long) }
          row(:orderable_until) { l(delivery.orderable_until, date_format: :long) }
          row(:depots) { Depot.where(id: delivery.depot_ids).pluck(:name).join(', ')}
        end
        attributes_table title: GroupBuying::Order.model_name.human(count: 2) do
          row(t('.open_orders')) {
            link_to(delivery.orders.open.count, group_buying_orders_path(q: { delivery_id_eq: delivery.id }, scope: 'open'))
          }
          row(t('.closed_orders')) {
            link_to(delivery.orders.closed.count, group_buying_orders_path(q: { delivery_id_eq: delivery.id }, scope: 'closed'))
          }
          row(t('.total_row')) {
            link = link_to(delivery.orders.all_without_canceled.count, group_buying_orders_path(q: { delivery_id_eq: delivery.id }))
            if (canceled_count = delivery.orders.canceled.count) > 0
              canceled_link = link_to(t('.orders_canceled', count: canceled_count), group_buying_orders_path(q: { delivery_id_eq: delivery.id }, scope: 'canceled'))
              link += " (#{canceled_link})".html_safe
            end
            link.html_safe
          }

        end
        panel GroupBuying::Delivery.human_attribute_name(:description) do
          delivery.description
        end
        active_admin_comments
      end
    end
  end

  action_item :xlsx, only: :show do
    link_to('XLSX', group_buying_delivery_path(resource, format: :xlsx), class: 'xlsx_link')
  end

  form do |f|
    f.inputs t('.details') do
      f.input :date, as: :datepicker, required: true
      f.input :orderable_until, as: :datepicker, required: true
    end
    f.inputs do
      translated_input(f, :descriptions, as: :action_text)
    end
    f.inputs Depot.model_name.human(count: 2) do
      f.input :depot_ids,
        collection: Depot.all,
        as: :check_boxes,
        label: Depot.model_name.human(count: 2),
        hint: t('formtastic.hints.group_buying/delivery.depot_ids')
    end
    f.actions
  end

  permit_params(
    :date,
    :orderable_until,
    *I18n.available_locales.map { |l| "description_#{l}" },
    depot_ids: [])

  controller do
    include TranslatedCSVFilename

    def apply_sorting(chain)
      params[:order] ||= 'date_asc' if params[:scope] == 'coming'
      super
    end

    def show
      respond_to do |format|
        format.html
        format.xlsx do
          if params[:producer_id]
            producer = GroupBuying::Producer.find(params[:producer_id])
          end
          xlsx = XLSX::GroupBuying::Delivery.new(resource, producer)
          send_data xlsx.data,
            content_type: xlsx.content_type,
            filename: xlsx.filename
        end
      end
    end
  end

  config.sort_order = 'date_desc'
end
