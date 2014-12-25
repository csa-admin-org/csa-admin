ActiveAdmin.register Basket do
  menu parent: 'Autre', priority: 10

  index do
    column :name
    column :year
    column :annual_price, ->(basket) { number_to_currency(basket.annual_price)}
    column :annual_halfday_works
    actions if current_admin.email == 'thibaud@thibaud.gg'
  end

  config.filters = false
  config.per_page = 50
end
