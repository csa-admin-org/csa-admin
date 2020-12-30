ActiveAdmin.register BasketSize do
  menu parent: :other, priority: 10
  actions :all, except: [:show]

  index download_links: false do
    column :name
    column :price, ->(bs) { cur(bs.price, precision: 3) }
    column :annual_price, ->(bs) { cur(bs.annual_price) }
    if Current.acp.share?
      column :acp_shares_number
    end
    if Current.acp.feature?('activity')
      column activity_scoped_attribute(:activity_participations_demanded_annualy), ->(bs) { bs.activity_participations_demanded_annualy }
    end
    actions class: 'col-actions-2'
  end

  form do |f|
    f.inputs do
      translated_input(f, :names)
      f.input :price
      if Current.acp.share?
        f.input :acp_shares_number, as: :number, step: 1
      end
      if Current.acp.feature?('activity')
        f.input :activity_participations_demanded_annualy,
          label: BasketSize.human_attribute_name(activity_scoped_attribute(:activity_participations_demanded_annualy))
      end
    end
    f.actions
  end

  permit_params(
    :price,
    :acp_shares_number,
    :activity_participations_demanded_annualy,
    names: I18n.available_locales)

  controller do
    include TranslatedCSVFilename
  end

  config.filters = false
  config.sort_order = 'price_desc'
end
