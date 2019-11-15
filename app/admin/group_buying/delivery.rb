ActiveAdmin.register GroupBuying::Delivery do
  menu parent: :group_buying, priority: 2

  scope :all
  scope :coming, default: true
  scope :past

  filter :date
  filter :during_year,
    as: :select,
    collection: -> { fiscal_years_collection }

  includes :orders

  index download_links: false do
    column '#', ->(delivery) { auto_link delivery, delivery.id }
    column :date, ->(delivery) { auto_link delivery, l(delivery.date) }
    column :orderable_until, ->(delivery) { auto_link delivery, l(delivery.orderable_until) }
    actions
  end

  show do |delivery|
    attributes_table do
      row :id
      row(:date) { l(delivery.date, date_format: :long) }
      row(:orderable_until) { l(delivery.orderable_until, date_format: :long) }
      row(:orders_count) {
        link_to(delivery.orders.count, group_buying_orders_path(q: { delivery_id_eq: delivery.id }))
      }
    end
    panel GroupBuying::Delivery.human_attribute_name(:description) do
      delivery.description
    end
    active_admin_comments
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

  config.sort_order = 'date_asc'
end
