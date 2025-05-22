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
    column :id, ->(dc) { link_to dc.id, dc }
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
      auto_link dc, txt
    }, class: "text-right whitespace-nowrap"
    column Current.org.fiscal_year_for(1.year.from_now), ->(dc) {
      txt = dc.future_deliveries_count.to_s
      if dc.future_deliveries_count.positive? && dc.absences_included_annually.positive?
        txt += " (-#{dc.absences_included_annually})"
      end
      auto_link dc, txt
    }, class: "text-right whitespace-nowrap"
    if DeliveryCycle.visible?
      column :visible, ->(dc) { status_tag dc.visible? }, class: "text-right"
    end
    actions
  end

  sidebar_handbook_link("deliveries#cycles-de-livraisons")

  show do |dc|
    columns do
      column do
        panel deliveries_current_year_title, count: dc.current_deliveries_count do
          if dc.current_deliveries_count.positive?
            table_for dc.current_deliveries, class: "table-auto" do
              column "#", ->(d) { auto_link d, d.number }
              column :date, ->(d) { auto_link d, l(d.date, format: :long) }
            end
          else
            div(class: "missing-data") { t("active_admin.empty") }
          end
        end
        panel deliveries_next_year_title, count: dc.future_deliveries_count do
          if dc.future_deliveries_count.positive?
            table_for dc.future_deliveries, class: "table-auto" do
              column "#", ->(d) { auto_link d, d.number }
              column :date, ->(d) { auto_link d, l(d.date, format: :long) }
            end
          else
            div(class: "missing-data") { t("active_admin.empty") }
          end
        end
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
                  column Depot.model_name.human, ->(d) { auto_link d }, class: "text-left"
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
            row(:week_numbers) { t("delivery_cycle.week_numbers.#{dc.week_numbers}") }
            row(:months) {
              if dc.months.size == 12
                t("active_admin.scopes.all")
              else
                dc.months.map { |m| t("date.month_names")[m].capitalize }.to_sentence
              end
            }
            row(:results) { t("delivery_cycle.results.#{dc.results}") }
            row(:minimum_gap_in_days) { dc.minimum_gap_in_days }
          end
        end

        active_admin_comments_for(dc)
      end
    end
  end

  form do |f|
    f.inputs t(".details") do
      render partial: "public_name", locals: { f: f, resource: resource, context: self }
    end

    unless DeliveryCycle.basket_size_config?
      f.inputs t("active_admin.resource.show.member_new_form") do
        f.input :member_order_priority,
          collection: member_order_priorities_collection,
          as: :select,
          prompt: true,
          hint: t("formtastic.hints.organization.member_order_priority_html")
        translated_input(f, :form_details,
          hint: t("formtastic.hints.delivery_cycle.form_detail"),
          placeholder: ->(locale) {
            I18n.with_locale(locale) {
              delivery_cycle_details(f.object, force_default: true)
            }
          })
        f.input :depots,
          as: :check_boxes,
          disabled: depot_ids_with_only(f.object)
      end
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
      f.input :wdays,
        as: :check_boxes,
        collection: wdays_collection,
        required: true
      f.input :months,
        as: :check_boxes,
        collection: months_collection(fiscal_year_order: true),
        required: true
      f.input :week_numbers,
        as: :select,
        collection: week_numbers_collection,
        include_blank: false,
        wrapper_html: { class: "[&>p]:text-red-500" }
      f.input :results,
        as: :select,
        collection: results_collection,
        include_blank: false
      f.input :minimum_gap_in_days
    end

    f.actions
  end

  permit_params(
    :visible,
    :member_order_priority,
    :price, :absences_included_annually,
    :week_numbers,
    :results,
    :minimum_gap_in_days,
    *I18n.available_locales.map { |l| "public_name_#{l}" },
    *I18n.available_locales.map { |l| "admin_name_#{l}" },
    *I18n.available_locales.map { |l| "invoice_name_#{l}" },
    *I18n.available_locales.map { |l| "form_detail_#{l}" },
    wdays: [],
    months: [],
    depot_ids: [])

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
