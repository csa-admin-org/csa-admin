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

  filter :title_cont,
   label: -> { Newsletter::Segment.human_attribute_name(:title) }

  sidebar :info, only: :index do
    side_panel t(".info") do
      para t("newsletters.segment.info_html")
    end
  end

  index download_links: false do
    column :title, sortable: true
    column Member.model_name.human(count: 2), ->(s) {
      s.members.count
    }, class: "text-right tabular-nums"
    column Newsletter.model_name.human(count: 2), ->(s) {
      link_to s.newsletters.count, newsletters_path(q: { segment_eq: s.id })
    }, class: "text-right tabular-nums"
    actions
  end

  sidebar_handbook_link("newsletters")

  form do |f|
    f.inputs t(".details"), icon: "notebook-text" do
      translated_input(f, :titles, required: true)
    end

    h3 t("newsletters.segment.criterias")
    para t("newsletters.segment.criterias_explanation_html")

    f.inputs Member.model_name.human(count: 2), icon: "users" do
      f.input :member_state,
        as: :select,
        collection: member_state_collection(exclude: %w[pending]),
        include_blank: true,
        hint: t("formtastic.hints.newsletter/segment.member_state")

      f.input :city,
        as: :select,
        collection: member_cities_collection,
        include_blank: true,
        hint: t("formtastic.hints.newsletter/segment.city")

      f.input :member_ids,
        as: :text,
        input_html: { rows: 2 },
        hint: (t("formtastic.hints.newsletter/segment.member_ids") +
          " <strong>#{t('formtastic.hints.newsletter/segment.member_ids_exclusive')}</strong>").html_safe
    end

    membership_scope_present = f.object.membership_scope.present?
    disabled_input_html = {
      disabled: !membership_scope_present,
      data: { form_disabler_target: "input" }
    }
    disabled_label_html = {
      class: membership_scope_present ? nil : "disabled",
      data: { form_disabler_target: "label" }
    }

    f.inputs Membership.model_name.human(count: 2), icon: "calendar-range",
      data: { controller: "form-disabler" } do
      f.input :membership_scope,
        as: :select,
        collection: Newsletter::Segment::MEMBERSHIP_SCOPES.map { |s|
          [ t("newsletters.segment.membership_scope.#{s}"), s ]
        },
        include_blank: true,
        hint: t("formtastic.hints.newsletter/segment.membership_scope"),
        input_html: {
          data: { action: "change->form-disabler#toggleInputs" }
        }

      f.input :basket_size_ids,
        as: :check_boxes,
        for: BasketSize,
        wrapper_html: { class: "single-column" },
        collection: admin_basket_sizes,
        label: BasketSize.model_name.human(count: 2),
        input_html: disabled_input_html,
        label_html: disabled_label_html,
        disabled: membership_scope_present ? [] : admin_basket_sizes.map(&:id)

      if BasketComplement.kept.any?
        f.input :basket_complement_ids,
          collection: admin_basket_complements,
          as: :check_boxes,
          for: BasketComplement,
          label: BasketComplement.model_name.human(count: 2),
          input_html: disabled_input_html,
          label_html: disabled_label_html,
          disabled: membership_scope_present ? [] : admin_basket_complements.map(&:id)
      end

      f.input :depot_ids,
        collection: admin_depots,
        as: :check_boxes,
        for: Depot,
        label: Depot.model_name.human(count: 2),
        hint: t("formtastic.hints.newsletter/segment.depot_ids"),
        grouped_collection: admin_depots_grouped_collection,
        input_html: disabled_input_html,
        label_html: disabled_label_html,
        disabled: membership_scope_present ? [] : admin_depots.map(&:id)

      if DeliveryCycle.kept.many?
        f.input :delivery_cycle_ids,
          collection: admin_delivery_cycles_collection,
          as: :check_boxes,
          for: DeliveryCycle,
          label: DeliveryCycle.model_name.human(count: 2),
          hint: t("formtastic.hints.newsletter/segment.delivery_cycle_ids"),
          input_html: disabled_input_html,
          label_html: disabled_label_html,
          disabled: membership_scope_present ? [] : admin_delivery_cycles.map(&:id)
      end

      f.input :first_membership,
        as: :select,
        collection: [ [ t("boolean.yes"), true ], [ t("boolean.no"), false ] ],
        include_blank: true,
        hint: t("formtastic.hints.newsletter/segment.first_membership"),
        input_html: disabled_input_html,
        label_html: disabled_label_html

      f.input :coming_deliveries_in_days,
        input_html: disabled_input_html,
        label_html: disabled_label_html

      f.input :renewal_state,
        as: :select,
        collection: renewal_states_collection,
        include_blank: true,
        hint: t("formtastic.hints.newsletter/segment.renewal_state"),
        input_html: disabled_input_html,
        label_html: disabled_label_html

      f.input :billing_year_division,
        as: :select,
        collection: billing_year_divisions_collection,
        include_blank: true,
        hint: t("formtastic.hints.newsletter/segment.billing_year_division"),
        input_html: disabled_input_html,
        label_html: disabled_label_html
    end

    f.actions
  end

  permit_params(
    :membership_scope,
    :renewal_state,
    :first_membership,
    :coming_deliveries_in_days,
    :billing_year_division,
    :member_ids,
    :member_state,
    :city,
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

  config.sort_order = "title_asc"
  config.per_page = 20
end
