# frozen_string_literal: true

ActiveAdmin.register DeliveryCycle do
  menu false

  breadcrumb do
    links = [ link_to(Delivery.model_name.human(count: 2), deliveries_path) ]
    if params[:action] != "index"
      links << link_to(DeliveryCycle.model_name.human(count: 2), delivery_cycles_path)
    end
    if params["action"].in? %W[edit]
      links << auto_link(resource)
    end
    links
  end

  filter :name_cont,
    label: -> { DeliveryCycle.human_attribute_name(:name) },
    as: :string
  filter :depots, as: :select,  collection: -> { admin_depots_collection }

  includes :depots
  index download_links: false do
    column :id
    column :name, ->(dc) { link_to display_name_with_public_name(dc), dc }, sortable: true
    if DeliveryCycle.prices?
      column :price, ->(d) { cur(d.price) }, class: "text-right tabular-nums whitespace-nowrap"
    end
    column :next_delivery, ->(dc) { auto_link dc.next_delivery }, class: "text-right whitespace-nowrap"
    column Current.org.current_fiscal_year, ->(dc) {
      txt = dc.current_deliveries_count.to_s
      if dc.current_deliveries_count.positive? && dc.absences_included_annually.positive?
        txt += " (-#{dc.absences_included_annually})"
      end
      txt
    }, class: "text-right whitespace-nowrap"
    column Current.org.fiscal_year_for(1.year.from_now), ->(dc) {
      txt = dc.future_deliveries_count.to_s
      if dc.future_deliveries_count.positive? && dc.absences_included_annually.positive?
        txt += " (-#{dc.absences_included_annually})"
      end
      txt
    }, class: "text-right whitespace-nowrap"
    if DeliveryCycle.visible?
      column :visible, ->(dc) { status_tag dc.visible? }, class: "text-right"
    else
      column "", ->(dc) { status_tag(:primary) if dc.primary? }, class: "text-right"
    end
    actions
  end

  sidebar_handbook_link("deliveries#cycles-de-livraisons")

  show do |dc|
    columns do
      column do
        deliveries_panel = ->(title, deliveries) {
          panel title, count: deliveries.count do
            if deliveries.any?
              table_for deliveries, class: "table-auto" do
                column "#", ->(d) { d.number }
                column :day, ->(d) { I18n.t("date.day_names")[d.date.wday] }, class: "text-right"
                column :date, ->(d) { auto_link d, l(d.date, format: :day_month), aria: { label: "show" } }, class: "text-right"
                column :cweek, ->(d) { d.date.cweek }, class: "text-right"
                unless Current.fiscal_year.standard?
                  column :year, ->(d) { d.date.year }, class: "text-right"
                end
              end
            else
              div(class: "missing-data") { t("active_admin.empty") }
            end
          end
        }

        deliveries_panel.call(deliveries_current_year_title, dc.current_deliveries)
        deliveries_panel.call(deliveries_next_year_title, dc.future_deliveries)
      end

      column do
        panel t(".details") do
          attributes_table do
            row :id
            row(:name) { dc.public_name }
            if dc.public_name?
              row(:admin_name) { dc.name }
            end
          end
        end

        if DeliveryCycle.visible?
          panel t(".member_new_form") do
            attributes_table do
              row(:visible, class: "text-right") { status_tag(dc.visible?) }
              if dc.visible?
                row(:form_detail, class: "text-right") { delivery_cycle_details(dc) }
              end
            end
            if dc.visible?
                table_for dc.depots, class: "mt-4" do
                  column Depot.model_name.human, ->(d) { auto_link d, aria: { label: "show" } }, class: "text-left"
                  column :visible, class: "text-right"
                end
            end
          end
        end

        panel t(".billing") do
          attributes_table do
            row(:price) { cur(dc.price) }
            row(:invoice_name) { dc.invoice_name }
            if feature?("absence")
              row :absences_included_annually
            end
          end
        end

        panel t("delivery_cycle.settings") do
          attributes_table do
            row(:wdays) {
              if dc.wdays.size == 7
                t("active_admin.scopes.all")
              else
                dc.wdays.map { |d| t("date.day_names")[d].capitalize }.to_sentence
              end
            }
            if dc.first_cweek?
              row(:first_cweek) { dc.first_cweek }
            end
            if dc.last_cweek?
              row(:last_cweek) { dc.last_cweek }
            end
            if dc.first_cweek? && dc.last_cweek?
              row(:exclude_cweek_range) { status_tag dc.exclude_cweek_range? }
            end
            row(:week_numbers) { t("delivery_cycle.week_numbers.#{dc.week_numbers}") }
          end
        end

        panel DeliveryCycle::Period.model_name.human(count: 2) do
          table_for dc.periods.order(:from_fy_month) do
            column t("delivery_cycle.period.fy_months"), ->(p) {
              from_month = fy_month_name(p.from_fy_month)
              to_month = fy_month_name(p.to_fy_month)
              if p.from_fy_month == p.to_fy_month
                from_month
              else
                [ from_month, to_month ].join(" – ")
              end
            }, class: "whitespace-nowrap"
            column Delivery.model_name.human(count: 2), ->(p) {
              t("delivery_cycle.results.#{p.results}")
            }, class: "text-right"
            column t("delivery_cycle.period.minimum_gap"), ->(p) {
              p.minimum_gap_in_days || "–"
            }, class: "text-right"
          end
        end

        active_admin_comments_for(dc)
      end
    end
  end

  form do |f|
    if f.object.persisted? && Delivery.current_year_ongoing? && f.object.current_year_memberships?
      current_memberships_count = f.object.memberships.current_year.count
      warning_pane do
        t("active_admin.resources.delivery_cycle.ongoing_fiscal_year_warning_html", year: Current.fiscal_year, count: current_memberships_count).html_safe
      end
    end

    f.inputs t(".details") do
      render partial: "public_name", locals: { f: f, resource: resource, context: self }
    end

    f.inputs t("active_admin.resource.show.member_new_form") do
      f.input :member_order_priority,
        collection: member_order_priorities_collection,
        as: :select,
        prompt: true,
        hint: t("formtastic.hints.organization.member_order_priority_html")
      translated_input(f, :form_details,
        hint: t("formtastic.hints.delivery_cycle.form_detail"),
        placeholder: ->(locale) {
          if f.object.persisted? && !f.object.form_detail?(locale)
            I18n.with_locale(locale) {
              delivery_cycle_details(f.object, force_default: true)
            }
          end
        })
      li class: "subtitle" do
        h2 t(".visibility")
        para t(".visibility_hint"), class: "description"
      end
      f.input :depots,
        as: :check_boxes,
        hint: true,
        disabled: depot_ids_with_only(f.object)
    end

    if feature?("absence")
      f.inputs t(".billing") do
        f.input :price,
          min: 0,
          hint: true,
          label: DeliveryCycle.human_attribute_name(:price_per_delivery)
        translated_input(f, :invoice_names,
          required: false,
          hint: t("formtastic.hints.delivery_cycle.invoice_name"),
          input_html: { placeholder: f.object.invoice_description })
        f.input :absences_included_annually
        handbook_button(self, "absences", anchor: "absences-incluses")
      end
    end

    f.inputs t("delivery_cycle.settings") do
      para t("formtastic.hints.delivery_cycle.settings_intro"), class: "description -mt-2 mb-4"
      f.input :wdays,
        as: :check_boxes,
        collection: wdays_collection,
        required: true
      div data: { controller: "cweek-range" } do
        div class: "single-line" do
          f.input :first_cweek,
            as: :select,
            collection: (1..53).to_a,
            include_blank: true,
            hint: t("formtastic.hints.delivery_cycle.first_cweek.#{Current.fiscal_year.standard? ? 'standard' : 'cross_year'}"),
            input_html: { data: { cweek_range_target: "firstCweek", action: "change->cweek-range#updateCheckboxState" } }
          f.input :last_cweek,
            as: :select,
            collection: (1..53).to_a,
            include_blank: true,
            hint: t("formtastic.hints.delivery_cycle.last_cweek.#{Current.fiscal_year.standard? ? 'standard' : 'cross_year'}"),
            input_html: { data: { cweek_range_target: "lastCweek", action: "change->cweek-range#updateCheckboxState" } }
        end
        f.input :exclude_cweek_range,
          input_html: { data: { cweek_range_target: "excludeCheckbox" }, disabled: f.object.first_cweek.blank? || f.object.last_cweek.blank? },
          hint: true
      end
      f.input :week_numbers,
        as: :select,
        collection: week_numbers_collection,
        include_blank: false,
        wrapper_html: { class: "[&>p]:text-red-500" },
        input_html: { class: "w-40" }

      handbook_button(self, "deliveries", anchor: "settings")
    end

    f.inputs DeliveryCycle::Period.model_name.human(count: 2) do
      para t("formtastic.hints.delivery_cycle.periods_intro"), class: "description -mt-2 mb-4"
      f.semantic_errors :periods
      f.has_many :periods, allow_destroy: true, new_record: t("delivery_cycle.add_period"), heading: nil do |ff|
        ff.input :from_fy_month,
          as: :select,
          required: false,
          include_blank: false,
          collection: fy_months_collection,
          wrapper_html: { class: "period-months" },
          hint: fy_months_next_year_hint
        ff.input :to_fy_month,
          as: :select,
          required: false,
          include_blank: false,
          collection: fy_months_collection,
          wrapper_html: { class: "period-months" },
          hint: fy_months_next_year_hint
        ff.input :results,
          as: :select,
          collection: results_collection,
          required: false,
          include_blank: false
        ff.input :minimum_gap_in_days
      end

      handbook_button(self, "deliveries", anchor: "periods")
    end

    f.actions
  end

  permit_params(
    :visible,
    :member_order_priority,
    :price, :absences_included_annually,
    :week_numbers,
    :first_cweek,
    :last_cweek,
    :exclude_cweek_range,
    *I18n.available_locales.map { |l| "public_name_#{l}" },
    *I18n.available_locales.map { |l| "admin_name_#{l}" },
    *I18n.available_locales.map { |l| "invoice_name_#{l}" },
    *I18n.available_locales.map { |l| "form_detail_#{l}" },
    wdays: [],
    depot_ids: [],
    periods_attributes: [ :id, :from_fy_month, :to_fy_month, :results, :minimum_gap_in_days, :_destroy ])

  before_build do |cycle|
    cycle.periods.build if cycle.periods.empty?
  end

  controller do
    include DeliveryCyclesHelper

    def scoped_collection
      super.kept
    end

    private

    def assign_attributes(resource, attributes)
      if attributes.first[:depot_ids]
        attributes.first[:depot_ids] += depot_ids_with_only(resource).map(&:to_s)
        attributes.first[:depot_ids].uniq!
      end
      super(resource, attributes)
    end
  end

  order_by(:name) do |clause|
    config
      .resource_class
      .order_by_name(clause.order)
      .order_values
      .join(" ")
  end

  config.sort_order = "name_asc"
  config.paginate = false
end
