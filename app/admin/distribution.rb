ActiveAdmin.register Distribution do
  menu parent: 'Autre', priority: 10

  index download_links: false do
    column :name
    column :address
    column :zip
    column :city
    column :price do |distribution|
      number_to_currency(distribution.price)
    end
    actions
  end

  show do |distribution|
    attributes_table do
      row :name
      row :address
      row :zip
      row :city
      row(:price) { number_to_currency(distribution.price) }
      row :emails
    end
  end

  permit_params *%i[name address zip city price emails]

  config.filters = false
  config.per_page = 25
end
