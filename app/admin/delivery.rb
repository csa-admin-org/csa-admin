ActiveAdmin.register Delivery do
  menu parent: 'Autre', priority: 10

  index do
    column '#', ->(delivery) { Delivery.pluck(:date).index(delivery.date) + 1 }
    column :date
    actions if current_admin.email == 'thibaud@thibaud.gg'
  end

  config.filters = false
  config.sort_order = 'date_asc'
  config.per_page = 50
end
