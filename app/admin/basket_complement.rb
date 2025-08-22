# frozen_string_literal: true

ActiveAdmin.register BasketComplement do
  menu parent: :other, priority: 9, label: -> { t("active_admin.menu.basket_complements") }
  actions :all, except: [ :show ]

  scope :all
  scope :visible, default: true
  scope :hidden

  includes :memberships_basket_complements, :baskets_basket_complement, :shop_product
  index download_links: false do
    column :id
    column :name, ->(bc) { display_name_with_public_name(bc) }, sortable: true
    column :price, ->(bc) { cur(bc.price) }, class: "text-right tabular-nums whitespace-nowrap"
    column :annual_price, ->(bc) {
      if bc.deliveries_count.positive?
        deliveries_based_price_info(bc.price, bc.billable_deliveries_counts)
      end
    }, class: "text-right tabular-nums whitespace-nowrap"
    column :deliveries, ->(bc) {
      deliveries_count_range(bc.billable_deliveries_counts)
    }, class: "text-right tabular-nums"
    column Current.org.current_fiscal_year, ->(bc) {
      link_to bc.current_deliveries.size, deliveries_path(
        q: {
          basket_complements_id_eq: bc.id,
          during_year: Current.org.current_fiscal_year.year
        },
        scope: :all)
    }, class: "text-right tabular-nums"
    column Current.org.fiscal_year_for(1.year.from_now), ->(bc) {
      link_to bc.future_deliveries.size, deliveries_path(
        q: {
          basket_complements_id_eq: bc.id,
          during_year: Current.org.current_fiscal_year.year + 1
        },
        scope: :all)
    }, class: "text-right tabular-nums"
    if feature?("activity")
      column activities_human_name,
        ->(bc) { bc.activity_participations_demanded_annually },
        class: "text-right tabular-nums",
        sortable: :activity_participations_demanded_annually
    end
    column :visible, class: "text-right"
    actions
  end

  form do |f|
    f.inputs t(".details") do
      render partial: "public_name", locals: { f: f, resource: resource, context: self }
    end

    f.inputs t(".billing") do
      f.input :price,
        min: 0,
        hint: f.object.persisted?,
        label: BasketComplement.human_attribute_name(:price_per_delivery)
      if feature?("activity")
        f.input :activity_participations_demanded_annually,
          label: BasketSize.human_attribute_name(activity_scoped_attribute(:activity_participations_demanded_annually)),
          as: :number,
          step: 1,
          min: 0
      end
    end

    f.inputs t("active_admin.resource.show.member_new_form") do
      f.input :member_order_priority,
        collection: member_order_priorities_collection,
        as: :select,
        prompt: true,
        hint: t("formtastic.hints.organization.member_order_priority_html")
      f.input :visible, as: :select, include_blank: false
      translated_input(f, :form_details,
        hint: t("formtastic.hints.basket_complement.form_detail"),
        placeholder: ->(locale) {
          if f.object.persisted? && !f.object.form_detail?(locale)
            I18n.with_locale(locale) {
              basket_complement_details(f.object, force_default: true)
            }
          end
        })
    end

    f.inputs Delivery.model_name.human(count: 2) do
      if Delivery.current_year.any?
        f.input :current_deliveries,
          label: Current.fiscal_year.to_s,
          as: :check_boxes,
          collection: Delivery.current_year,
          hint: f.object.persisted? ? t("formtastic.hints.basket_complement.current_deliveries_html") : nil
      end
      if Delivery.future_year.any?
        f.input :future_deliveries,
          label: Current.org.next_fiscal_year.to_s,
          as: :check_boxes,
          collection: Delivery.future_year,
          hint: f.object.persisted?
      end

      handbook_button(self, "deliveries", anchor: "complments-de-panier")
    end

    f.actions
  end

  permit_params(
    :price,
    :activity_participations_demanded_annually,
    :visible,
    :member_order_priority,
    *I18n.available_locales.map { |l| "public_name_#{l}" },
    *I18n.available_locales.map { |l| "admin_name_#{l}" },
    *I18n.available_locales.map { |l| "form_detail_#{l}" },
    current_delivery_ids: [],
    future_delivery_ids: [])

  controller do
    include TranslatedCSVFilename

    def scoped_collection
      super.kept
    end
  end

  order_by(:name) do |clause|
    config
      .resource_class
      .order_by_name(clause.order)
      .order_values
      .join(" ")
  end

  config.filters = false
  config.sort_order = "name_asc"
  config.paginate = false
end
