# frozen_string_literal: true

ActiveAdmin.register Depot do
  menu parent: :other, priority: 5

  scope :all
  scope :visible, default: true
  scope :hidden

  filter :name_cont,
    label: -> { Depot.human_attribute_name(:name) },
    as: :string
  filter :group, as: :select
  filter :city_cont,
    label: -> { Depot.human_attribute_name(:city) },
    as: :string
  filter :delivery_cycles,
    as: :select,
    collection: -> { admin_delivery_cycles_collection }

  includes :memberships, :delivery_cycles
  index do
    column :id
    column :name, ->(d) { display_name_with_public_name(d) }, sortable: true
    if DepotGroup.any?
      column :group
    end
    if Depot.prices?
      column :price, ->(d) { cur(d.price) }, class: "text-right tabular-nums whitespace-nowrap"
    end
    if DeliveryCycle.visible?
      column :delivery_cycles, ->(d) {
        div class: "flex justify-end flex-wrap gap-1" do
          d.delivery_cycles.ordered.map { |cycle|
            delivery_cycle_link(cycle)
          }.join.html_safe
        end
      }, class: "text-right"
    end
    column :visible, class: "text-right"
    actions
  end

  member_action :move_to, method: :patch do
    authorize!(:update, Depot)
    depot = Depot.find(params[:id])
    delivery = Delivery.find(params[:delivery_id])
    depot.move_to(params[:position].to_i, delivery)
    head :ok
  end

  member_action :move_member_to, method: :patch do
    authorize!(:update, Depot)
    depot = Depot.find(params[:id])
    member = Member.find(params[:member_id])
    delivery = Delivery.find(params[:delivery_id])
    depot.move_member_to(params[:position].to_i, member, delivery)
    head :ok
  end

  csv do
    column(:id)
    column(:name)
    column(:public_name)
    if Current.org.languages.many?
      column(:language) { |d| t("languages.#{d.language}") }
    end
    column(:group) { |d| d.group&.name }
    column(:price) { |d| cur(d.price) }
    column(:note)
    column(:address_name)
    column(:address)
    column(:zip)
    column(:visible)
    column(:contact_name)
    column(:emails) { |d| d.emails_array.join(", ") }
    column(:phones) { |d| d.phones_array.map(&:phony_formatted).join(", ") }
  end

  action_item :depot_group, only: :index do
    link_to DepotGroup.model_name.human(count: 2), depot_groups_path, class: "action-item-button"
  end

  show do |depot|
    columns do
      column do
        if delivery = params[:delivery_id] ? Delivery.find(params[:delivery_id]) : depot.next_delivery
          panel t("active_admin.page.index.next_delivery", delivery: link_to(delivery.display_name(format: :long), delivery)).html_safe, action: (
            icon_file_link(:xlsx, delivery_path(delivery, format: :xlsx, depot_id: depot.id), title: Delivery.human_attribute_name(:summary)) +
            icon_file_link(:pdf, delivery_path(delivery, format: :pdf, depot_id: depot.id), target: "_blank", title: Delivery.human_attribute_name(:sheets))
          ) do
            attrs = {}
            if authorized?(:update, depot) && depot.delivery_sheets_mode == "home_delivery"
              attrs[:class] = "cursor-move table-auto"
              attrs[:tbody_html] = { data: { controller: "sortable" } }
              attrs[:row_html] = ->(b) {
                { data: { "sortable-update-url" => "/depots/#{b.depot_id}/move_member_to?delivery_id=#{b.delivery_id}&member_id=#{b.member.id}" } }
              }
            end

            table_for(depot.baskets_for(delivery), **attrs) do
              column Member.model_name.human, ->(b) { auto_link b.member }
              column Basket.model_name.human, ->(b) { link_to(b.description, b.membership) }
            end
          end
        else
          panel t("active_admin.page.index.no_next_delivery") do
            div class: "missing-data" do
              link_to t("active_admin.page.index.no_next_deliveries"), deliveries_path
            end
          end
        end
      end
      column do
        panel t(".details") do
          attributes_table do
            row :id
            row(:name) { depot.public_name }
            if depot.public_name?
              row(:admin_name) { depot.name }
            end
            row(:group)
            if Current.org.languages.many?
              row(:language) { t("languages.#{depot.language}") }
            end
            row(:note) { text_format(depot.note) }
            row(:public_note) { depot.public_note if depot.public_note? }
          end
        end

        panel t(".billing") do
          attributes_table do
            row(:price) { cur(depot.price) }
          end
        end

        panel Delivery.human_attribute_name(:sheets_pdf) do
          attributes_table do
            row(:delivery_sheets_mode) { t("delivery.sheets_mode.#{depot.delivery_sheets_mode}") }
            row(Announcement.model_name.human(count: 2)) {
              count = Announcement.depots_eq(depot.id).active.count
              link_to t("announcements.active", count: count), announcements_path(scope: :active, q: { depots_eq: depot.id })
            }
          end
        end

        panel t(".member_new_form") do
          attributes_table do
            row(:visible, class: "text-right") { status_tag(depot.visible?) }
            if depot.visible?
              row(:form_detail, class: "text-right") { depot_details(depot) }
            end
          end
          if DeliveryCycle.visible?
            table_for depot.delivery_cycles, class: "table-auto" do
              column DeliveryCycle.model_name.human, ->(dc) { auto_link dc, aria: { label: "show" } }
              column Current.org.current_fiscal_year, ->(dc) {
                dc.current_deliveries_count
              }, class: "text-right"
              column Current.org.fiscal_year_for(1.year.from_now), ->(dc) {
                dc.future_deliveries_count
              }, class: "text-right"
            end
          end
        end

        panel Depot.human_attribute_name(:address) do
          attributes_table do
            row :address_name
            row :address
            row :zip
            row :city
          end
        end

        panel Depot.human_attribute_name(:contact) do
          attributes_table do
            row :contact_name
            row(:emails) { display_emails_with_link(self, depot.emails_array) }
            row(:phones) { display_phones_with_link(self, depot.phones_array) }
          end
        end

        active_admin_comments_for(depot)
      end
    end
  end

  form do |f|
    f.inputs t(".details") do
      render partial: "public_name", locals: { f: f, resource: resource, context: self }
      f.input :group,
        as: :select,
        hint: t("formtastic.hints.depot.group_html")
      language_input(f)
      f.input :note, input_html: { rows: 3 }
      translated_input(f, :public_notes,
        as: :action_text,
        required: false,
        hint: t("formtastic.hints.depot.public_note"))
    end

    f.inputs t(".billing") do
      f.input :price,
        min: 0,
        hint: true,
        label: Depot.human_attribute_name(:price_per_delivery)
    end

    f.inputs Delivery.human_attribute_name(:sheets_pdf) do
      f.input :delivery_sheets_mode,
        as: :radio,
        collection: Depot::DELIVERY_SHEETS_MODES.map { |mode|
          [
            content_tag(:span, class: "ms-2 py-0.5 leading-5") {
              content_tag(:span, t("delivery.sheets_mode.#{mode}"), class: "block font-medium") +
              content_tag(:span, t("delivery.sheets_mode.#{mode}_hint").html_safe, class: "inline-hints")
            },
            mode
          ]
        }
    end

    f.inputs t("active_admin.resource.show.member_new_form") do
      f.input :visible, as: :select, include_blank: false
      f.input :member_order_priority,
        collection: member_order_priorities_collection,
        as: :select,
        prompt: true,
        hint: t("formtastic.hints.organization.member_order_priority_html")
      translated_input(f, :form_details,
        hint: t("formtastic.hints.depot.form_detail"),
        placeholder: ->(locale) {
          if f.object.persisted? && !f.object.form_detail?(locale)
            I18n.with_locale(locale) { depot_details(f.object) }
          end
        })
      unless DeliveryCycle.basket_size_config?
        f.input :delivery_cycles,
          collection: admin_delivery_cycles_collection,
          input_html: f.object.persisted? ? {} : { checked: true },
          as: :check_boxes,
          required: true
      end
    end

    f.inputs Depot.human_attribute_name(:address) do
      f.input :address_name
      f.input :address
      div class: "single-line" do
        f.input :zip, wrapper_html: { class: "md:w-50" }
        f.input :city, wrapper_html: { class: "w-full" }
      end
    end

    f.inputs Depot.human_attribute_name(:contact) do
      f.input :contact_name
      f.input :emails, as: :string
      f.input :phones, as: :string
    end

    f.actions
  end

  permit_params(
    *%i[
      language
      group_id
      price visible note
      address_name address zip city
      contact_name emails phones
      member_order_priority
      delivery_sheets_mode
    ],
    *I18n.available_locales.map { |l| "public_name_#{l}" },
    *I18n.available_locales.map { |l| "admin_name_#{l}" },
    *I18n.available_locales.map { |l| "public_note_#{l}" },
    *I18n.available_locales.map { |l| "form_detail_#{l}" },
    delivery_cycle_ids: [])

  before_build do |depot|
    depot.price ||= 0.0
  end

  controller do
    include TranslatedCSVFilename
    include DeliveryCyclesHelper

    def scoped_collection
      super.kept
    end
  end

  order_by("name") do |clause|
    config
      .resource_class
      .reorder_by_name(clause.order)
      .order_values
      .join(" ")
  end

  config.sort_order = "name_asc"
  config.paginate = false
end
