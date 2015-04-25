ActiveAdmin.register Basket do
  menu parent: 'Autre', priority: 10

  index do
    column :name
    column :year
    column :annual_price, ->(basket) { number_to_currency(basket.annual_price)}
    column :annual_halfday_works
    actions if current_admin.email == 'thibaud@thibaud.gg'
  end

  show do |basket|
    attributes_table do
      row :name
      row :year
      row(:annual_price) { number_to_currency(basket.annual_price) }
      row :annual_halfday_works
    end
  end

  config.filters = false
  config.per_page = 25
end
