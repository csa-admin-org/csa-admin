ActiveAdmin.register BasketSize do
  menu parent: :other, priority: 10
  actions :all, except: [:show]

  includes :memberships
  index download_links: false do
    column :name
    column :price, ->(bs) { cur(bs.price, precision: 3) }
    column :annual_price, ->(bs) {
      if bs.price.positive?
        deliveries_based_price_info(bs.price) + " (#{deliveries_count})"
      end
    }
    if Current.acp.feature?('activity')
      column activity_scoped_attribute(:activity_participations_demanded_annualy), ->(bs) { bs.activity_participations_demanded_annualy }
    end
    if Current.acp.share?
      column :acp_shares_number
    end
    actions class: 'col-actions-2'
  end

  form do |f|
    f.inputs do
      translated_input(f, :names, required: true)
      f.input :price, as: :number, min: 0
      if Current.acp.feature?('activity')
        f.input :activity_participations_demanded_annualy,
          label: BasketSize.human_attribute_name(activity_scoped_attribute(:activity_participations_demanded_annualy)),
          as: :number,
          step: 1,
          min: 0
      end
      if Current.acp.share?
        f.input :acp_shares_number, as: :number, step: 1
      end
    end
    f.actions
  end

  permit_params(
    :price,
    :acp_shares_number,
    :activity_participations_demanded_annualy,
    *I18n.available_locales.map { |l| "name_#{l}" })

  controller do
    include TranslatedCSVFilename
  end

  config.filters = false
  config.sort_order = 'price_desc'
end
