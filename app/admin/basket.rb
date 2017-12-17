ActiveAdmin.register Basket do
  menu parent: 'Autre', priority: 10

  index download_links: false do
    column :name
    column :annual_price, ->(basket) { number_to_currency(basket.annual_price)}
    actions
  end

  show do |basket|
    attributes_table do
      row :name
      row(:annual_price) { number_to_currency(basket.annual_price) }
    end
  end

  permit_params *%i[name annual_price]

  config.filters = false
end
