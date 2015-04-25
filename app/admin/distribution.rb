ActiveAdmin.register Distribution do
  menu parent: 'Autre', priority: 10

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

  show do |distribution|
    attributes_table do
      row :name
      row :address
      row :zip
      row :city
      row(:basket_price) { number_to_currency(distribution.basket_price) }
    end
  end

  permit_params *%i[name address zip city basket_price]

  config.filters = false
  config.per_page = 25
end
