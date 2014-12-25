ActiveAdmin.register Distribution do
  menu parent: 'Autre', priority: 10
  actions :all, except: [:show]

  index do
    column :name
    column :address
    column :zip
    column :city
    column :basket_price do |distribution|
      number_to_currency(distribution.basket_price)
    end
    actions
  end

  config.filters = false
  config.per_page = 50
end
