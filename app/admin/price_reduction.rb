# frozen_string_literal: true

ActiveAdmin.register PriceReduction do
  menu parent: :other, priority: 8

  breadcrumb do
    links = []
    unless params[:action] == "index"
      links << link_to(PriceReduction.model_name.human(count: 2), price_reductions_path)
    end
    if params[:action] != "index"
      links << auto_link(resource) if params[:action].in?(%w[edit])
    end
    links
  end

  scope :all
  scope :visible, group: :visibility, default: true
  scope :hidden, group: :visibility

  includes :price_reduction_card

  filter :cap_mode, as: :select, collection: -> { price_reduction_cap_modes_collection }
  filter :price_reduction_card,
    as: :select,
    collection: -> { PriceReductionCard.order_by_name.map { |card| [ card.name, card.id ] } }
  filter :renew
  filter :visible

  action_item :price_reduction_cards, only: :index do
    action_link PriceReductionCard.model_name.human(count: 2), price_reduction_cards_path, icon: "id-card"
  end

  index download_links: false do
    column :name, ->(reduction) { display_name_with_public_name(reduction) }, sortable: true
    column t("active_admin.resource.form.rule"), ->(reduction) { reduction.rule_label }, class: "text-right tabular-nums"
    column :granted, ->(reduction) { cur(reduction.granted_amount(reduction.fiscal_year_cap? ? Current.fy_year : nil)) }, class: "text-right tabular-nums"
    column :remaining, ->(reduction) {
      remaining = reduction.remaining_amount(reduction.fiscal_year_cap? ? Current.fy_year : nil)
      remaining.nil? ? "–" : cur(remaining)
    }, class: "text-right tabular-nums"
    column :price_reduction_card, ->(reduction) { reduction.price_reduction_card&.name }, class: "text-right"
    column :visible, ->(reduction) { aligned_status_tag(reduction.visible?) }, class: "text-right"
    actions
  end

  show do |reduction|
    years = reduction.show_fiscal_years
    selected_year = params[:year].presence&.to_i || Current.fy_year
    selected_year = Current.fy_year unless years.any? { |fy| fy.year == selected_year }
    year_grants = reduction.membership_price_reductions.joins(:membership).merge(Membership.during_year(selected_year))
    membership_count = year_grants.count
    year_granted = year_grants.sum(:amount)
    average = membership_count.zero? ? 0 : year_granted / membership_count
    granted = reduction.fiscal_year_cap? || !reduction.capped? ? year_granted : reduction.granted_amount

    columns do
      column do
        panel nil, class: "is-year-stats" do
          nav class: "tabs-nav year-tabs", role: "tablist" do
            years.each do |fy|
              text_node link_to(
                fy.to_s,
                price_reduction_path(reduction, year: fy.year),
                role: "tab",
                "aria-selected": (fy.year == selected_year).to_s)
            end
          end

          ul class: "pair-grid" do
            li do
              counter_tag(
                link_to(
                  Membership.model_name.human(count: membership_count),
                  memberships_path(scope: :all, q: {
                    with_price_reduction: reduction.id,
                    during_year: selected_year
                  })),
                membership_count)
            end
            li { counter_tag(PriceReduction.human_attribute_name(:average), average, type: :currency) }
            li { counter_tag(PriceReduction.human_attribute_name(:granted), granted, type: :currency) }
            if reduction.capped?
              remaining = reduction.remaining_amount(reduction.fiscal_year_cap? ? selected_year : nil)
              li { counter_tag(PriceReduction.human_attribute_name(:remaining), remaining, type: :currency) }
            end
          end

          if year_grants.any?
            table_for year_grants.includes(membership: :member), class: "table-auto" do
              column(Member.model_name.human) { |grant| auto_link grant.membership.member }
              column(:amount, class: "text-right tabular-nums") { |grant| cur(grant.amount) }
              column(Membership.model_name.human, class: "text-right") { |grant|
                auto_link grant.membership, grant.membership.id, data: { "table-row-action": "show" }
              }
            end
          end
        end
      end

      column do
        panel t("active_admin.resource.show.details"), icon: "notebook-text" do
          attributes_table do
            row(:name) { display_name_with_public_name(reduction) }
            row(:visible) { aligned_status_tag(reduction.visible?) }
            row(:waiting) { reduction.waiting_members.kept.count }
          end
        end

        panel t("active_admin.resource.form.rule"), icon: "ticket-percent" do
          attributes_table do
            if reduction.percentage
              row(:percentage) { reduction.rule_label }
            elsif reduction.fixed_amount
              row(:fixed_amount) { reduction.rule_label }
            end
            row(:renew) { aligned_status_tag(reduction.renew?) }
            row(:price_reduction_card) { auto_link reduction.price_reduction_card if reduction.price_reduction_card }
          end
        end

        panel t("active_admin.resource.form.cap"), icon: "coins" do
          attributes_table do
            row(:cap_amount) { reduction.capped? ? cur(reduction.cap_amount) : "–" }
            row(:cap_mode) { PriceReduction.human_attribute_name("cap_mode/#{reduction.cap_mode}") if reduction.capped? }
          end
        end

        panel t("active_admin.resource.form.availability"), icon: "map" do
          attributes_table do
            row(:depots) {
              if reduction.all_depots?
                t("active_admin.scopes.all")
              else
                safe_join(reduction.depots.map { |depot| auto_link(depot) }, ", ")
              end
            }
          end
        end
      end
    end
  end

  form do |f|
    f.inputs t(".details"), icon: "notebook-text" do
      render partial: "public_name", locals: { f: f, resource: resource, context: self }
    end

    f.inputs t(".rule"), icon: "ticket-percent" do
      div class: "single-line is-paired", data: { controller: "form-exclusive" } do
        exclusive = {
          data: {
            form_exclusive_target: "input",
            action: "input->form-exclusive#sync"
          }
        }
        f.input :percentage, min: 0.01, max: 100, step: 0.01, required: false, input_html: exclusive.deep_dup
        span t("formtastic.or"), class: "single-line-separator"
        f.input :fixed_amount, min: 0.05, step: 0.05, required: false, input_html: exclusive.deep_dup
        para price_reduction_handbook_hint(:cut, "programs"), class: "inline-hints"
      end

      f.input :renew, as: :boolean, hint: price_reduction_handbook_hint(:renew, "renewal")
      f.input :price_reduction_card,
        as: :select,
        collection: PriceReductionCard.order_by_name,
        include_blank: true,
        hint: price_reduction_handbook_hint(:card, "cards")
    end

    f.inputs t(".cap"), icon: "coins",
      action: handbook_icon_link("price_reductions", anchor: "cap") do
      if f.object.persisted? && f.object.capped?
        granted = f.object.fiscal_year_cap? ? f.object.granted_amount(Current.fy_year) : f.object.granted_amount
        para t("formtastic.hints.price_reduction.already_granted", amount: cur(granted)), class: "description"
      end
      f.input :cap_mode,
        as: :select,
        collection: price_reduction_cap_modes_collection,
        include_blank: false,
        required: false,
        hint: price_reduction_handbook_hint(:cap_mode, "cap")
      f.input :cap_amount,
        min: 0.05,
        step: 0.05,
        required: false,
        hint: price_reduction_handbook_hint(:cap_amount, "cap")
    end

    f.inputs t(".availability"), icon: "map" do
      f.input :depot_ids,
        as: :check_boxes,
        collection: Depot.kept.order_by_name,
        hint: t("formtastic.hints.price_reduction.depot_ids")
    end

    f.inputs t("active_admin.resource.show.member_new_form"), icon: "form",
      action: (if Handbook.new("price_reductions", nil).filepath.exist?
        handbook_icon_link("price_reductions", anchor: "programs")
               end),
      "data-controller" => "form-details-preview",
      "data-form-details-preview-url-value" => form_details_preview_price_reductions_path do
      f.input :visible, as: :select, include_blank: false
      f.input :member_order_priority,
        collection: member_order_priorities_collection,
        as: :select,
        prompt: true,
        hint: t("formtastic.hints.organization.member_order_priority_html")
      translated_input(f, :form_details,
        required: false,
        hint: t("formtastic.hints.price_reduction.form_detail"),
        input_html: { data: { form_details_preview_target: "input" } },
        placeholder: ->(locale) {
          I18n.with_locale(locale) { f.object.placeholder_form_detail }
        })
      text_node form_details_preview_frame(
        "price-reduction",
        form_details_preview_placeholders(f.object, :price_reduction_form_detail))
    end

    f.actions
  end

  permit_params :percentage, :fixed_amount, :cap_amount, :cap_mode,
    :renew, :visible, :member_order_priority, :price_reduction_card_id,
    *I18n.available_locales.map { |locale| "public_name_#{locale}" },
    *I18n.available_locales.map { |locale| "admin_name_#{locale}" },
    *I18n.available_locales.map { |locale| "form_detail_#{locale}" },
    depot_ids: []

  collection_action :form_details_preview, method: :get do
    authorize! :read, PriceReduction
    placeholders = helpers.form_details_preview_placeholders(
      helpers.form_details_preview_price_reduction(params[:price_reduction]),
      :price_reduction_form_detail)
    render html: helpers.form_details_preview_frame("price-reduction", placeholders)
  end

  controller do
    include MembersHelper

    def scoped_collection
      super.kept
    end
  end
end
