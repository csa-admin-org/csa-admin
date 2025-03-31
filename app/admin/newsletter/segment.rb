# frozen_string_literal: true

ActiveAdmin.register Newsletter::Segment do
  menu false
  actions :all, except: [ :show ]

  breadcrumb do
    links = [ link_to(Newsletter.model_name.human(count: 2), newsletters_path) ]
    if params[:action] != "index"
      links << link_to(Newsletter::Segment.model_name.human(count: 2), newsletter_segments_path)
    end
    links
  end

  sidebar :info, only: :index do
    side_panel t(".info") do
      para t("newsletters.segment.info_html")
    end
  end

  index download_links: false do
    column :title, ->(s) { link_to s.title, [ :edit, s ] }, sortable: true
    column Member.model_name.human(count: 2), ->(s) { s.members.count }, sortable: false, class: "text-right"
    actions
  end

  sidebar_handbook_link("newsletters", only: :index)

  form do |f|
    f.inputs t(".details") do
      translated_input(f, :titles, required: true)
    end

    f.inputs t("newsletters.segment.criterias") do
      f.input :basket_size_ids,
        as: :check_boxes,
        wrapper_html: { class: "single-column" },
        collection: admin_basket_sizes,
        label: BasketSize.model_name.human(count: 2),
        hint: t("formtastic.hints.newsletter/segment.basket_size_ids")
      if BasketComplement.kept.any?
        f.input :basket_complement_ids,
          collection: admin_basket_complements,
          as: :check_boxes,
          label: BasketComplement.model_name.human(count: 2),
          hint: t("formtastic.hints.newsletter/segment.basket_complement_ids")
      end
      f.input :depot_ids,
        collection: admin_depots,
        as: :check_boxes,
        label: Depot.model_name.human(count: 2),
        hint: t("formtastic.hints.newsletter/segment.depot_ids")
      if DeliveryCycle.kept.many?
        f.input :delivery_cycle_ids,
          collection: admin_delivery_cycles_collection,
          as: :check_boxes,
          label: DeliveryCycle.model_name.human(count: 2),
          hint: t("formtastic.hints.newsletter/segment.delivery_cycle_ids")
      end
      f.input :first_membership,
        as: :select,
        collection: [ [ t("boolean.yes"), true ], [ t("boolean.no"), false ] ],
        include_blank: true,
        hint: t("formtastic.hints.newsletter/segment.first_membership")
      f.input :coming_deliveries_in_days,
        hint: t("formtastic.hints.newsletter/segment.coming_deliveries_in_days")
      f.input :renewal_state,
        as: :select,
        collection: renewal_states_collection,
        include_blank: true,
        hint: t("formtastic.hints.newsletter/segment.renewal_state")
      f.input :billing_year_division,
        as: :select,
        collection: billing_year_divisions_collection,
        include_blank: true,
        hint: t("formtastic.hints.newsletter/segment.billing_year_division")
    end

    f.actions
  end

  permit_params(
    :renewal_state,
    :first_membership,
    :coming_deliveries_in_days,
    :billing_year_division,
    *I18n.available_locales.map { |l| "title_#{l}" },
    basket_size_ids: [],
    basket_complement_ids: [],
    depot_ids: [],
    delivery_cycle_ids: [])

  order_by(:title) do |clause|
    config
      .resource_class
      .order_by_title(clause.order)
      .order_values
      .join(" ")
  end

  config.filters = false
  config.sort_order = "title_asc"
end
