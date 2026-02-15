# frozen_string_literal: true

ActiveAdmin.register BasketSize do
  menu parent: :other, priority: 10, label: -> { t("active_admin.menu.basket_sizes") }
  actions :all, except: [ :show ]

  scope :all
  scope :visible, group: :visibility, default: true
  scope :hidden, group: :visibility

  includes :memberships
  index download_links: false do
    column :id
    column :name, ->(bs) { display_name_with_public_name(bs) }, sortable: true
    column :price, ->(bs) { cur(bs.price, precision: 3) }, class: "text-right tabular-nums whitespace-nowrap"
    column :annual_price, ->(bs) {
      if bs.price.positive?
        deliveries_based_price_info(bs.price, bs.billable_deliveries_counts)
      end
    }, class: "text-right tabular-nums whitespace-nowrap"
    column :deliveries, ->(bs) {
      deliveries_count_range(bs.billable_deliveries_counts)
    }, class: "text-right tabular-nums"
    if feature?("activity")
      column activities_human_name,
        ->(bs) { bs.activity_participations_demanded_annually },
        class: "text-right tabular-nums",
        sortable: :activity_participations_demanded_annually
    end
    if Current.org.share?
      column t("billing.shares"), ->(bs) { bs.shares_number }, class: "text-right tabular-nums", sortable: :shares_number
    end
    column :visible, class: "text-right"
    actions
  end

  form do |f|
    f.inputs t(".details") do
      render partial: "public_name", locals: { f: f, resource: resource, context: self }
    end

    f.inputs t(".billing") do
      price_hint = []
      price_hint << t("formtastic.hints.basket_size.price") if f.object.persisted?
      price_hint << t("formtastic.hints.basket_size.price_zero")
      f.input :price,
        min: 0,
        hint: price_hint.join("<br/>").html_safe,
        label: BasketSize.human_attribute_name(:price_per_delivery)
      if feature?("activity")
        f.input :activity_participations_demanded_annually,
          label: BasketSize.human_attribute_name(activity_scoped_attribute(:activity_participations_demanded_annually)),
          as: :number,
          step: 1,
          min: 0
      end
      if Current.org.share?
        f.input :shares_number, as: :number, step: 1
      end
    end

    f.inputs t("active_admin.resources.basket_size.edit.availability") do
      para t("active_admin.resources.basket_size.edit.availability_hint"), class: "description -mt-2 mb-4"
      div class: "single-line" do
        f.input :first_cweek,
          as: :select,
          collection: (1..53).to_a,
          include_blank: true,
          hint: t("formtastic.hints.basket_size.first_cweek.#{Current.fiscal_year.standard? ? 'standard' : 'cross_year'}")
        f.input :last_cweek,
          as: :select,
          collection: (1..53).to_a,
          include_blank: true,
          hint: t("formtastic.hints.basket_size.last_cweek.#{Current.fiscal_year.standard? ? 'standard' : 'cross_year'}")
      end
    end

    f.inputs t("active_admin.resource.show.member_new_form") do
      f.input :visible, as: :select, include_blank: false
      f.input :member_order_priority,
        collection: member_order_priorities_collection,
        as: :select,
        prompt: true,
        hint: t("formtastic.hints.organization.member_order_priority_html")
      translated_input(f, :form_details,
        hint: t("formtastic.hints.basket_size.form_detail"),
        placeholder: ->(locale) {
          if f.object.persisted? && !f.object.form_detail?(locale)
            I18n.with_locale(locale) {
              basket_size_details(f.object, force_default: true)
            }
          end
        })
    end

    f.actions
  end

  permit_params(
    :price,
    :shares_number,
    :activity_participations_demanded_annually,
    :visible,
    :member_order_priority,
    :first_cweek,
    :last_cweek,
    *I18n.available_locales.map { |l| "public_name_#{l}" },
    *I18n.available_locales.map { |l| "admin_name_#{l}" },
    *I18n.available_locales.map { |l| "form_detail_#{l}" })

  before_build do |basket_size|
    basket_size.shares_number ||= Current.org.shares_number
  end

  controller do
    include TranslatedCSVFilename
    include DeliveryCyclesHelper
    include MembersHelper

    def scoped_collection
      super.kept
    end
  end

  order_by(:name) do |clause|
    config
      .resource_class
      .unscoped
      .order_by_name(clause.order)
      .order_values
      .join(" ")
  end

  config.filters = false
  config.sort_order = "price_asc"
  config.paginate = false
end
