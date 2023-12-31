ActiveAdmin.register BasketSize do
  menu parent: :other, priority: 10, label: -> { t("active_admin.menu.basket_sizes") }
  actions :all, except: [ :show ]

  scope :all
  scope :visible, default: true
  scope :hidden

  includes :memberships
  index download_links: false do
    column :id
    column :name, ->(bs) { display_name_with_public_name(bs) }
    column :price, ->(bs) { cur(bs.price, precision: 3) }
    column :annual_price, ->(bs) {
      if bs.price.positive?
        deliveries_based_price_info(bs.price, bs.deliveries_counts)
      end
    }
    column :deliveries, ->(bs) {
      deliveries_count_range(bs.deliveries_counts)
    }
    if Current.acp.feature?("activity")
      column activities_human_name,
        ->(bs) { bs.activity_participations_demanded_annualy },
        class: "col-activities"
    end
    if Current.acp.share?
      column t("billing.acp_shares"), ->(bs) { bs.acp_shares_number }
    end
    column :visible
    if authorized?(:update, BasketSize)
      actions class: "col-actions-2"
    end
  end

  form do |f|
    f.inputs do
      translated_input(f, :names)
      translated_input(f, :public_names,
        hint: t("formtastic.hints.basket_size.public_name"))
      f.input :price, as: :number, min: 0, hint: f.object.persisted?
      if Current.acp.feature?("activity")
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

    f.inputs t("active_admin.resource.show.member_new_form") do
      f.input :visible, as: :select, include_blank: false
      f.input :member_order_priority,
        collection: member_order_priorities_collection,
        as: :select,
        prompt: true,
        hint: t("formtastic.hints.acp.member_order_priority_html")
      translated_input(f, :form_details,
        hint: t("formtastic.hints.basket_size.form_detail"),
        placeholder: ->(locale) {
          if f.object.persisted?
            I18n.with_locale(locale) {
              basket_size_details(f.object, force_default: true)
            }
          end
        })
      if !DeliveryCycle.visible? && DeliveryCycle.many?
        f.input :delivery_cycle, collection: delivery_cycles_collection
      end
    end

    f.actions
  end

  permit_params(
    :price,
    :acp_shares_number,
    :activity_participations_demanded_annualy,
    :visible,
    :member_order_priority,
    :delivery_cycle_id,
    *I18n.available_locales.map { |l| "name_#{l}" },
    *I18n.available_locales.map { |l| "public_name_#{l}" },
    *I18n.available_locales.map { |l| "form_detail_#{l}" })

  controller do
    include TranslatedCSVFilename
    include DeliveryCyclesHelper
    include MembersHelper
  end

  config.filters = false
  config.sort_order = "price_asc"
  config.paginate = false
end
