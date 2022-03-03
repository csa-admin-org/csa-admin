ActiveAdmin.register BasketSize do
  menu parent: :other, priority: 10, label: -> { t('active_admin.menu.basket_sizes') }
  actions :all, except: [:show]

  includes :memberships
  index download_links: false do
    column :name
    column :price, ->(bs) { cur(bs.price, precision: 3) }
    column :annual_price, ->(bs) {
      if bs.price.positive?
        deliveries_based_price_info(bs.price).to_s + " (#{deliveries_count})"
      end
    }
    if Current.acp.feature?('activity')
      column activities_human_name, ->(bs) { bs.activity_participations_demanded_annualy }
    end
    if Current.acp.share?
      column t('billing.acp_shares'), ->(bs) { bs.acp_shares_number }
    end
    column :visible
    if authorized?(:update, BasketSize)
      actions class: 'col-actions-2'
    end
  end

  form do |f|
    f.inputs do
      translated_input(f, :names, required: true)
      translated_input(f, :public_names,
        required: false,
        hint: t('formtastic.hints.basket_size.public_name'))
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

    f.inputs t('active_admin.resource.show.member_new_form') do
      f.input :form_priority, hint: true
      f.input :visible, as: :select, include_blank: false
    end

    f.actions
  end

  permit_params(
    :price,
    :visible,
    :acp_shares_number,
    :activity_participations_demanded_annualy,
    :form_priority,
    *I18n.available_locales.map { |l| "name_#{l}" },
    *I18n.available_locales.map { |l| "public_name_#{l}" })

  controller do
    include TranslatedCSVFilename
  end

  config.filters = false
  config.sort_order = 'price_asc'
end
