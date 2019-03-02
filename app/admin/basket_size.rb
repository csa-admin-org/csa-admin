ActiveAdmin.register BasketSize do
  menu parent: :other, priority: 10
  actions :all, except: [:show]

  index download_links: false do
    column :name
    column :price, ->(bs) { number_to_currency(bs.price, precision: 3) }
    column :annual_price, ->(bs) { number_to_currency(bs.annual_price) }
    if Current.acp.share?
      column :acp_shares_number
    end
    column activity_scoped_attribute(:activity_participations_demanded_annualy), ->(bs) { bs.activity_participations_demanded_annualy }
    actions
  end

  form do |f|
    f.inputs do
      translated_input(f, :names)
      f.input :price
      if Current.acp.share?
        f.input :acp_shares_number, as: :number, step: 1
      end
      f.input :activity_participations_demanded_annualy,
        label: BasketSize.human_attribute_name(activity_scoped_attribute(:activity_participations_demanded_annualy))
      f.actions
    end
  end

  permit_params(
    :price,
    :acp_shares_number,
    :activity_participations_demanded_annualy,
    names: I18n.available_locales)

  config.filters = false
  config.sort_order = -> { "names->>'#{I18n.locale}'" }
end
