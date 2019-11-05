ActiveAdmin.register GroupBuying::Delivery do
  menu parent: :group_buying, priority: 1

  scope :all
  scope :coming, default: true
  scope :past

  filter :date
  filter :during_year,
    as: :select,
    collection: -> { fiscal_years_collection }

  index do
    column '#', ->(delivery) { auto_link delivery, delivery.id }
    column :date, ->(delivery) { auto_link delivery, l(delivery.date) }
    column :orderable_until, ->(delivery) { auto_link delivery, l(delivery.orderable_until) }
    actions
  end

  show do |delivery|
    attributes_table do
      row(:date) { l(delivery.orderable_until, date_format: :long) }
      row(:orderable_until) { l(delivery.orderable_until, date_format: :long) }
      row :description
    end
  end

  form do |f|
    f.inputs t('.details') do
      f.input :date, as: :datepicker, required: true
      f.input :orderable_until, as: :datepicker, required: true
    end
    f.inputs do
      translated_input(f, :descriptions,
        as: :action_text,
        input_html: { rows: 10 })
    end
    f.actions
  end

  permit_params(
    :date,
    :orderable_until,
    descriptions: I18n.available_locales)

  controller do
    include TranslatedCSVFilename
  end

  config.sort_order = 'date_asc'
end
