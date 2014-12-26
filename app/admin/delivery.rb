ActiveAdmin.register Delivery do
  menu parent: 'Autre', priority: 10

  index do
    column '#', ->(delivery) { delivery.number }
    column :date
    actions if current_admin.email == 'thibaud@thibaud.gg'
  end

  show do |delivery|
    attributes_table do
      row('#') { delivery.number }
      row(:date) { l delivery.date }
    end
  end

  config.filters = false
  config.sort_order = 'date_asc'
  config.per_page = 50
end
