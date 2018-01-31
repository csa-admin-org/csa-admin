ActiveAdmin.register BasketComplement do
  menu parent: 'Autre', priority: 11
  actions :all, except: [:show]

  index download_links: false do
    column :name
    column :price, ->(bs) { number_to_currency(bs.price, precision: 3) }
    column :annual_price, ->(bs) { number_to_currency(bs.annual_price) }
    actions
  end

  form do |f|
    f.inputs do
      f.input :name
      f.input :price
      f.input :deliveries,
        as: :check_boxes,
        collection: Delivery.current_and_future_year,
        disabled: Delivery.current_year.past.pluck(:id),
        hint: f.object.persisted? && 'Tous les abonnements qui ont souscrit à ce complément seront automatiquement mis à jour en cas de changement.'
      f.actions
    end
  end

  permit_params :name, :price, delivery_ids: []

  config.filters = false
end
