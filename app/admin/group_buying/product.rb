ActiveAdmin.register GroupBuying::Product do
  menu parent: :group_buying, priority: 3
  actions :all, except: [:show]

  filter :producer
  filter :available
  filter :price

  index do
    column :name, ->(product) { auto_link product }, sortable: :names
    column :available, ->(product) { status_tag(product.available? ? :yes : :no) }
    column :price, ->(product) { number_to_currency(product.price) }
    actions
  end

  form do |f|
    f.inputs t('.details') do
      f.input :producer
      translated_input(f, :names)
      f.input :price, as: :number, step: 0.05, min: -99999.95, max: 99999.95
      f.input :available, as: :boolean
    end
    f.actions
  end

  permit_params(
    :producer_id,
    :available,
    :price,
    names: I18n.available_locales)

  config.sort_order = "names_desc"
end
