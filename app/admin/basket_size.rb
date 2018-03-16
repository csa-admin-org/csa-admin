ActiveAdmin.register BasketSize do
  menu parent: 'Autre', priority: 10
  actions :all, except: [:show]

  index download_links: false do
    column :name
    column :price, ->(bs) { number_to_currency(bs.price, precision: 3) }
    column :annual_price, ->(bs) { number_to_currency(bs.annual_price) }
    column halfday_scoped_attribute(:annual_halfday_works), ->(bs) { bs.annual_halfday_works }
    actions
  end

  form do |f|
    f.inputs do
      f.input :name
      f.input :price
      f.input :annual_halfday_works,
        label: BasketSize.human_attribute_name(halfday_scoped_attribute(:annual_halfday_works))
      f.actions
    end
  end

  permit_params(*%i[name price annual_halfday_works])

  config.filters = false
end
