ActiveAdmin.register BasketComplement do
  menu parent: :other, priority: 11
  actions :all, except: [:show]

  scope :all
  scope :visible, default: true
  scope :hidden

  includes :memberships_basket_complements
  index download_links: false do
    column :name
    column :price_type, -> (bc) {
      BasketComplement.human_attribute_name("price_type/#{bc.price_type}")
    }
    column :price, ->(bc) {
      if bc.annual_price_type?
        cur(bc.annual_price)
      else
        cur(bc.delivery_price)
      end
    }
    column :annual_price, ->(bc) {
      if bc.deliveries_count.positive?
        cur(bc.annual_price)
      end
    }
    column :visible
    column :deliveries_count, ->(bc) {
      link_to bc.deliveries_count, deliveries_path(
        q: {
          basket_complements_id_eq: bc.id,
          during_year: Current.acp.current_fiscal_year.year
        },
        scope: :all)
    }
    actions class: 'col-actions-2'
  end

  form do |f|
    f.inputs do
      translated_input(f, :names, required: true)
      f.input :price_type,
        as: :select,
        collection: BasketComplement::PRICE_TYPES.map { |type|
          [BasketComplement.human_attribute_name("price_type/#{type}"), type]
        }
      f.input :price, as: :number, min: 0
      f.input :visible, as: :select, hint: true, prompt: true, required: true
    end
    f.inputs do
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

  permit_params(:price, :price_type, :visible,
    current_delivery_ids: [],
    future_delivery_ids: [],
    names: I18n.available_locales)

  controller do
    include TranslatedCSVFilename
  end

  config.filters = false
  config.sort_order = -> { "names->>'#{I18n.locale}'" }
end
