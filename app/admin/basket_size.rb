ActiveAdmin.register BasketSize do
  menu parent: 'Autre', priority: 10
  actions :all, except: [:show]

  index download_links: false do
    column :name
    column :annual_price, ->(basket_size) { number_to_currency(basket_size.annual_price)}
    actions
  end

  form do |f|
    f.inputs do
      f.input :name
      f.input :annual_price
      f.actions
    end
  end

  permit_params *%i[name annual_price]

  config.filters = false
end
