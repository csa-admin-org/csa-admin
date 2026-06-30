# frozen_string_literal: true

ActiveAdmin.register Depot do
  menu parent: :other, priority: 5

  scope :all
  scope :visible, group: :visibility, default: true
  scope :hidden, group: :visibility

  filter :name_cont,
    label: -> { Depot.human_attribute_name(:name) },
    as: :string
  filter :group, as: :select
  filter :city_cont,
    label: -> { Depot.human_attribute_name(:city) },
    as: :string
  filter :delivery_cycles,
    as: :select,
    collection: -> { admin_delivery_cycles_collection_by_visibility }
  filter :delivery_sheets_mode,
    label: -> { I18n.t("active_admin.filters.labels.delivery_sheets_mode") },
    as: :select,
    collection: -> {
      Depot::DELIVERY_SHEETS_MODES.map { |mode|
        [ I18n.t("delivery.sheets_mode.#{mode}"), mode ]
      }
    }
  filter :maps_visible, as: :boolean, if: proc { feature?("maps") }
  filter :with_map_coordinates,
    label: -> { I18n.t("active_admin.filters.labels.with_map_coordinates") },
    as: :boolean,
    if: proc { feature?("maps") }

  includes :memberships, :delivery_cycles
  index do
    selectable_column(class: "w-px")
    column :id
    column :name, ->(d) { display_name_with_public_name(d) }, sortable: true
    if DepotGroup.any?
      column :group
    end
    if Depot.prices?
      column :price, ->(d) { cur(d.price, precision: 3) }, class: "text-right tabular-nums whitespace-nowrap"
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
    column :visible, ->(d) { aligned_status_tag(d.visible?) }, class: "text-right"
    if Current.org.feature?("maps")
      column t("active_admin.resources.depot.map"), ->(d) { aligned_status_tag(d.maps_visible?) }, class: "text-right"
    end
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

  member_action :geocode, method: :post do
    return head :not_found unless Current.org.feature?("maps")

    authorize!(:update, Depot)
    depot = Depot.find(params[:id])
    address = geocoding_address_for(depot)
    coordinates = depot.geocode_coordinates(address)

    respond_to do |format|
      format.json do
        if address.blank?
          render json: { error: t("active_admin.resources.depot.geocoding_unavailable") }, status: :unprocessable_entity
        elsif coordinates
          latitude, longitude = coordinates
          render json: { latitude: latitude, longitude: longitude }
        else
          render json: { error: t("active_admin.resources.depot.geocoding_failed") }, status: :unprocessable_entity
        end
      end

      format.html do
        if address.blank?
          redirect_back fallback_location: depot_path(depot), alert: t("active_admin.resources.depot.geocoding_unavailable")
        elsif coordinates && depot.update(latitude: coordinates.first, longitude: coordinates.last)
          redirect_back fallback_location: edit_depot_path(depot), notice: t("active_admin.resources.depot.geocoding_updated")
        else
          redirect_back fallback_location: edit_depot_path(depot), alert: t("active_admin.resources.depot.geocoding_failed")
        end
      end
    end
  end

  csv do
    column(:id)
    column(:name)
    column(:public_name)
    if Current.org.languages.many?
      column(:language) { |d| t("languages.#{d.language}") }
    end
    column(:group) { |d| d.group&.name }
    column(:price) { |d| cur(d.price, precision: 3) }
    column(:note)
    column(:address_name)
    column(:street)
    column(:zip)
    column(:visible)
    if Current.org.feature?("maps")
      column(:maps_visible)
      column(:latitude)
      column(:longitude)
    end
    column(:contact_name)
    column(:emails) { |d| d.emails_array.join(", ") }
    column(:phones) { |d| d.phones_array.map(&:phony_formatted).join(", ") }
  end

  action_item :depot_group, only: :index do
    action_link DepotGroup.model_name.human(count: 2), depot_groups_path, icon: "group"
  end

  show do |depot|
    columns do
      column do
        if delivery = params[:delivery_id] ? Delivery.find(params[:delivery_id]) : depot.next_delivery
          panel t("active_admin.page.index.next_delivery", delivery: link_to(delivery.display_name(format: :long), delivery)).html_safe, icon: "calendar", action: icon_file_links(
            icon_file_link(:xlsx, delivery_path(delivery, format: :xlsx, depot_id: depot.id), title: Delivery.human_attribute_name(:summary)),
            icon_file_link(:pdf, delivery_path(delivery, format: :pdf, depot_id: depot.id), title: Delivery.human_attribute_name(:sheets), target: "_blank")) do
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
              column Basket.model_name.human, ->(b) { link_to(b.description, b.membership, aria: { label: "show" }) }, class: "text-right"
            end
          end
        else
          panel t("active_admin.page.index.no_next_delivery"), icon: "calendar" do
            div class: "missing-data" do
              link_to t("active_admin.page.index.no_next_deliveries"), deliveries_path
            end
          end
        end
      end
      column do
        panel t(".details"), icon: "notebook-text" do
          attributes_table do
            row :id
            row(:name) { depot.public_name }
            if depot.public_name?
              row(:admin_name) { depot.name }
            end
            row(:group)
            row(:note) { text_format(depot.note) }
            row(:public_note) { depot.public_note if depot.public_note? }
          end
        end

        panel t(".billing"), icon: "banknotes" do
          attributes_table do
            row(:price) { cur(depot.price, precision: 3) }
            row(:invoice_name) { depot.invoice_name if depot.invoice_name? }
          end
        end

        panel Delivery.human_attribute_name(:sheets_pdf), icon: "file-spreadsheet" do
          attributes_table do
            row(:delivery_sheets_mode) { t("delivery.sheets_mode.#{depot.delivery_sheets_mode}") }
            row(Announcement.model_name.human(count: 2)) {
              count = Announcement.depots_eq(depot.id).active.count
              link_to t("announcements.active", count: count), announcements_path(scope: :active, q: { depots_eq: depot.id })
            }
          end
        end

        panel Admin.human_attribute_name(:notifications), icon: "mail-check", action: handbook_icon_link("deliveries", anchor: "depot-delivery-list-notifications") do
          attributes_table do
            row(:emails) { display_emails_with_link(self, depot.emails_array) }
            if Current.org.languages.many?
              row(:language) { t("languages.#{depot.language}") }
            end
          end
        end

        panel t(".member_new_form"), icon: "form", action: handbook_icon_link("registration", anchor: "depots") do
          attributes_table do
            row(:visible) { aligned_status_tag(depot.visible?) }
            if depot.visible?
              row(:form_detail) { depot_details(depot) }
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

        panel Depot.human_attribute_name(:street), icon: "map", action: handbook_icon_link("maps", anchor: "depot-review") do
          attributes_table do
            row :address_name
            row :street
            row :zip
            row :city
            if Current.org.feature?("maps")
              row(:maps_visible) { aligned_status_tag(depot.maps_visible?) }
              row(:position) { display_position(depot.latitude, depot.longitude) }
            end
          end

          if Current.org.feature?("maps") && depot.map_coordinates?
            render partial: "active_admin/depots/coordinate_map", locals: { depot: depot, editable: false }
          end
        end

        panel Depot.human_attribute_name(:contact), icon: "contact-round" do
          attributes_table do
            row :contact_name
            row(:phones) { display_phones_with_link(self, depot.phones_array) }
          end
        end

        active_admin_comments_for(depot)
      end
    end
  end

  form do |f|
    f.inputs t(".details"), icon: "notebook-text" do
      render partial: "public_name", locals: { f: f, resource: resource, context: self }
      f.input :group,
        as: :select,
        hint: t("formtastic.hints.depot.group_html")
      f.input :note, input_html: { rows: 3 }
      translated_input(f, :public_notes,
        as: :action_text,
        required: false,
        hint: t("formtastic.hints.depot.public_note"))
    end

    f.inputs t(".billing"), icon: "banknotes" do
      f.input :price,
        min: 0,
        hint: true,
        label: Depot.human_attribute_name(:price_per_delivery)
      translated_input(f, :invoice_names,
        required: false,
        hint: t("formtastic.hints.depot.invoice_name"),
        input_html: { placeholder: f.object.invoice_description })
    end

    f.inputs Delivery.human_attribute_name(:sheets_pdf), icon: "file-spreadsheet" do
      f.input :delivery_sheets_mode,
        as: :radio,
        required: false,
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

    f.inputs Admin.human_attribute_name(:notifications), icon: "mail-check" do
      f.input :emails, as: :string
      f.input :notify_days_before_delivery, as: :number, input_html: { min: 0 }
      language_input(f)

      handbook_button(self, "deliveries", anchor: "depot-delivery-list-notifications")
    end

    f.inputs t("active_admin.resource.show.member_new_form"), icon: "form" do
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
      f.input :delivery_cycles,
        collection: admin_delivery_cycles_collection,
        input_html: f.object.persisted? ? {} : { checked: true },
        as: :check_boxes,
        required: true

      handbook_button(self, "registration", anchor: "depots")
    end

    f.inputs Depot.human_attribute_name(:street), icon: "map" do
      f.input :address_name
      f.input :street
      div class: "single-line" do
        f.input :zip, wrapper_html: { class: "md:w-50" }
        f.input :city, wrapper_html: { class: "w-full" }
      end
      if Current.org.feature?("maps")
        f.input :maps_visible, as: :boolean
        div class: "single-line" do
          f.input :latitude, as: :number, input_html: { min: -90, max: 90, step: "any", inputmode: "decimal" }
          f.input :longitude, as: :number, input_html: { min: -180, max: 180, step: "any", inputmode: "decimal" }
        end
        render partial: "active_admin/depots/coordinate_map", locals: { depot: f.object, editable: true }
        handbook_button(self, "maps", anchor: "depot-review")
      end
    end

    f.inputs Depot.human_attribute_name(:contact), icon: "contact-round" do
      f.input :contact_name
      f.input :phones, as: :string
    end

    f.actions
  end

  permit_params(
    *%i[
      language
      group_id
      price visible note
      address_name street zip city
      maps_visible latitude longitude
      contact_name emails phones
      notify_days_before_delivery
      member_order_priority
      delivery_sheets_mode
    ],
    *I18n.available_locales.map { |l| "public_name_#{l}" },
    *I18n.available_locales.map { |l| "admin_name_#{l}" },
    *I18n.available_locales.map { |l| "public_note_#{l}" },
    *I18n.available_locales.map { |l| "form_detail_#{l}" },
    *I18n.available_locales.map { |l| "invoice_name_#{l}" },
    delivery_cycle_ids: [])

  batch_action :destroy, false

  batch_action :show_in_registration_form, if: proc { authorized?(:update, Depot) && params[:scope].in?([ "all", "hidden" ]) } do |selection|
    Depot.where(id: selection).update_all(visible: true)
    redirect_back fallback_location: collection_path
  end

  batch_action :hide_from_registration_form, if: proc { authorized?(:update, Depot) && params[:scope].in?([ nil, "all", "visible" ]) } do |selection|
    Depot.where(id: selection).update_all(visible: false)
    redirect_back fallback_location: collection_path
  end

  batch_action :show_on_maps, if: proc { authorized?(:update, Depot) && feature?("maps") } do |selection|
    depots = Depot.where(id: selection)
    depots_with_coordinates = depots.where.not(latitude: nil).where.not(longitude: nil)
    depots_with_coordinates.update_all(maps_visible: true)

    if depots_with_coordinates.count < depots.count
      redirect_back fallback_location: collection_path, alert: t("active_admin.resources.depot.maps_visible_skipped")
    else
      redirect_back fallback_location: collection_path
    end
  end

  batch_action :hide_from_maps, if: proc { authorized?(:update, Depot) && feature?("maps") } do |selection|
    Depot.where(id: selection).update_all(maps_visible: false)
    redirect_back fallback_location: collection_path
  end

  before_build do |depot|
    depot.price ||= 0.0
  end

  controller do
    include TranslatedCSVFilename
    include DeliveryCyclesHelper

    def scoped_collection
      super.kept
    end

    private

    def geocoding_address_for(depot)
      if params[:depot]
        attrs = params.fetch(:depot, {}).permit(:street, :zip, :city)
        depot.geocoding_address(street: attrs[:street], zip: attrs[:zip], city: attrs[:city])
      else
        depot.geocoding_address
      end
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
  config.batch_actions = true
  config.paginate = false
end
