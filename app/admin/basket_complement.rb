ActiveAdmin.register BasketComplement do
  menu parent: :other, priority: 9, label: -> { t("active_admin.menu.basket_complements") }
  actions :all, except: [ :show ]

  scope :all
  scope :visible, default: true
  scope :hidden

  includes :memberships_basket_complements, :baskets_basket_complement, :shop_product
  index download_links: false do
    column :id
    column :name, ->(bc) { display_name_with_public_name(bc) }
    column :price, ->(bc) { cur(bc.price) }
    column :annual_price, ->(bc) {
      if bc.deliveries_count.positive?
        deliveries_based_price_info(bc.price, bc.billable_deliveries_counts)
      end
    }
    column :deliveries, ->(bc) {
      deliveries_count_range(bc.billable_deliveries_counts)
    }
    column Current.acp.current_fiscal_year, ->(bc) {
      link_to bc.current_deliveries.size, deliveries_path(
        q: {
          basket_complements_id_eq: bc.id,
          during_year: Current.acp.current_fiscal_year.year
        },
        scope: :all)
    }, class: "col-deliveries"
    column Current.acp.fiscal_year_for(1.year.from_now), ->(bc) {
      link_to bc.future_deliveries.size, deliveries_path(
        q: {
          basket_complements_id_eq: bc.id,
          during_year: Current.acp.current_fiscal_year.year + 1
        },
        scope: :all)
    }, class: "col-deliveries"
    if Current.acp.feature?("activity")
      column activities_human_name,
        ->(bc) { bc.activity_participations_demanded_annualy },
        class: "col-activities"
    end
    column :visible
    if authorized?(:update, BasketComplement)
      actions class: "col-actions-2"
    end
  end

  form do |f|
    f.inputs do
      translated_input(f, :names)
      translated_input(f, :public_names,
        hint: t("formtastic.hints.basket_complement.public_name"))
      f.input :price, as: :number, min: 0, hint: f.object.persisted?
      if Current.acp.feature?("activity")
        f.input :activity_participations_demanded_annualy,
          label: BasketSize.human_attribute_name(activity_scoped_attribute(:activity_participations_demanded_annualy)),
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
        hint: t("formtastic.hints.acp.member_order_priority_html")
      f.input :visible, as: :select, include_blank: false
      translated_input(f, :form_details,
        hint: t("formtastic.hints.basket_complement.form_detail"),
        placeholder: ->(locale) {
          I18n.with_locale(locale) {
            basket_complement_details(f.object, force_default: true)
          }
        })
    end

    f.inputs do
      if Delivery.current_year.any?
        f.input :current_deliveries,
          label: deliveries_current_year_title,
          as: :check_boxes,
          collection: Delivery.current_year,
          hint: f.object.persisted? ? t("formtastic.hints.basket_complement.current_deliveries_html") : nil
      end
      if Delivery.future_year.any?
        f.input :future_deliveries,
          label: deliveries_next_year_title,
          as: :check_boxes,
          collection: Delivery.future_year,
          hint: f.object.persisted?
      end

      para class: "actions" do
        a href: handbook_page_path("deliveries", anchor: "complments-de-panier"), class: "action" do
          span do
            span inline_svg_tag("admin/book-open.svg", size: "20", title: t("layouts.footer.handbook"))
            span t(".check_handbook")
          end
        end.html_safe
      end
    end

    f.actions
  end

  permit_params(
    :price,
    :activity_participations_demanded_annualy,
    :visible,
    :member_order_priority,
    *I18n.available_locales.map { |l| "name_#{l}" },
    *I18n.available_locales.map { |l| "public_name_#{l}" },
    *I18n.available_locales.map { |l| "form_detail_#{l}" },
    current_delivery_ids: [],
    future_delivery_ids: [])

  controller do
    include TranslatedCSVFilename
  end

  config.filters = false
  config.sort_order = :default_scope
  config.paginate = false
end
