ActiveAdmin.register BasketComplement do
  menu parent: :other, priority: 11
  actions :all, except: [:show]

  index download_links: false do
    column :name
    column :price_type, -> (bs) {
      BasketComplement.human_attribute_name("price_type/#{bs.price_type}")
    }
    column :price, ->(bs) {
      if bs.annual_price_type?
        number_to_currency(bs.annual_price, precision: 2)
      else
        number_to_currency(bs.delivery_price, precision: 2) +
        " (#{number_to_currency(bs.annual_price, precision: 2)})"
      end
    }
    column :deliveries_count, ->(bs) {
      link_to bs.deliveries_count, deliveries_path(q: { basket_complements_id_eq: bs.id })
    }
    actions
  end

  form do |f|
    f.inputs do
      translated_input(f, :names)
      f.input :price_type,
        as: :select,
        collection: BasketComplement::PRICE_TYPES.map { |type|
          [BasketComplement.human_attribute_name("price_type/#{type}"), type]
        }
      f.input :price
      if Delivery.current_year.any?
        f.input :current_deliveries,
          as: :check_boxes,
          collection: Delivery.current_year,
          hint: f.object.persisted?
      end
      if Delivery.future_year.any?
        f.input :future_deliveries,
          as: :check_boxes,
          collection: Delivery.future_year,
          hint: f.object.persisted?
      end
    end
    f.actions
  end

  permit_params(:price, :price_type,
    current_delivery_ids: [],
    future_delivery_ids: [],
    names: I18n.available_locales)

  controller do
    include TranslatedCSVFilename
  end

  config.filters = false
  config.sort_order = -> { "names->>'#{I18n.locale}'" }
end
