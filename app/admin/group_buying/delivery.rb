ActiveAdmin.register GroupBuying::Delivery do
  menu parent: :group_buying, priority: 2

  scope :all
  scope :coming, default: true
  scope :past

  filter :date
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
    actions defaults: true do |delivery|
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
                column(:amount) { |i| number_to_currency(i.amount) }
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
    f.actions
  end

  permit_params(
    :date,
    :orderable_until,
    descriptions: I18n.available_locales)

  controller do
    include TranslatedCSVFilename

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

    def update
      super do |success, _failure|
        success.html { redirect_to root_path }
      end
    end
  end

  config.sort_order = 'date_asc'
end
