ActiveAdmin.register BasketSize do
  menu parent: :other, priority: 10
  actions :all, except: [:show]

  index download_links: false do
    column :name
    column :price, ->(bs) { number_to_currency(bs.price, precision: 3) }
    column :annual_price, ->(bs) { number_to_currency(bs.annual_price) }
    if Current.acp.share_price
      column :acp_shares_number
    end
    column halfday_scoped_attribute(:annual_halfday_works), ->(bs) { bs.annual_halfday_works }
    actions
  end

  form do |f|
    f.inputs do
      translated_input(f, :names)
      f.input :price
      if Current.acp.share_price
        f.input :acp_shares_number, as: :number, step: 1
      end
      f.input :annual_halfday_works,
        label: BasketSize.human_attribute_name(halfday_scoped_attribute(:annual_halfday_works))
      f.actions
    end
  end

  permit_params(
    :price,
    :acp_shares_number,
    :annual_halfday_works,
    names: I18n.available_locales)

  config.filters = false
  config.sort_order = -> { "names->>'#{I18n.locale}'" }
end
