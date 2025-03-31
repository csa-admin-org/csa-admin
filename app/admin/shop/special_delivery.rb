# frozen_string_literal: true

ActiveAdmin.register Shop::SpecialDelivery do
  menu parent: :navshop, priority: 4
  actions :all

  breadcrumb do
    if params["action"] == "index"
      [ t("active_admin.menu.shop") ]
    else
      links = [
        t("active_admin.menu.shop"),
        link_to(Shop::SpecialDelivery.model_name.human(count: 2), shop_special_deliveries_path)
      ]
      if params["action"].in? %W[edit]
        links << I18n.l(resource.date)
      end
      links
    end
  end

  scope :all
  scope :coming, default: true
  scope :past

  filter :during_year,
    as: :select,
    collection: -> { fiscal_years_collection }
  filter :date
  filter :wday, as: :select, collection: -> { wdays_collection }
  filter :month, as: :select, collection: -> { months_collection }
  filter :depot, as: :select, collection: -> { admin_depots_collection }

  # Workaround for ActionController::UnknownFormat (xlsx download)
  # https://github.com/activeadmin/activeadmin/issues/4945#issuecomment-302729459
  includes :shop_orders
  index download_links: -> { params[:action] == "show" ? [ :xlsx ] : false } do
    column :id, ->(d) { auto_link d, d.id }
    column :date, ->(d) { auto_link d, l(d.date, format: :medium) }
    column :open_until, ->(d) {
      if d.shop_open?
        l(d.shop_closing_at, format: :medium)
      else
        status_tag :closed, class: "red"
      end
    }, class: "text-right"
    column Shop::Product.model_name.human(count: 2), ->(d) {
      link_to(
        d.shop_products_count,
        edit_shop_special_delivery_path(d, anchor: "products"))
    }, sortable: :shop_products_count, class: "text-right"
    column :orders, ->(d) {
      link_to(
        d.shop_orders_count,
        shop_orders_path(
          q: { _delivery_gid_eq: d.gid }, scope: :all_without_cart))
    }, sortable: false, class: "text-right"
    actions do |delivery|
      icon_file_link(:xlsx, shop_special_delivery_path(delivery, format: :xlsx), size: 5) +
      icon_file_link(:pdf, delivery_shop_orders_path(delivery_gid: delivery.gid, format: :pdf), target: "_blank", size: 5)
    end
  end

  sidebar_shop_admin_only_warning

  sidebar_handbook_link("shop#livraisons-spciales")

  show title: ->(d) { d.display_name(format: :long).capitalize } do |delivery|
    columns do
      column do
        all = Shop::DeliveryTotal.all_by_producer(delivery)
        if all.empty?
          panel Shop::Order.model_name.human(count: 2) do
            div(class: "missing-data") { t(".no_orders") }
          end
        else
          all.each do |producer, items|
            panel producer.name, action: icon_file_link(:xlsx, shop_special_delivery_path(delivery, format: :xlsx, producer_id: producer.id)) do
              table_for items, i18n: Shop::OrderItem, class: "table-auto data-table-total" do
                column(:product) { |i| auto_link i.product }
                column(:product_variant) { |i| i.product_variant }
                column(:quantity, class: "text-right")
                column(:amount, class: "text-right") { |i|
                  span(class: "whitespace-nowrap") { cur(i.amount) }
                }
              end
            end
          end
        end
      end
      column do
        panel t(".details") do
          attributes_table do
            row(:title)
            row(:date) { l(delivery.date, format: :medium) }
            row(:products) {
              link_to(
                delivery.shop_products_count,
                edit_shop_special_delivery_path(delivery, anchor: "products"))
            }
            row(:orders) {
              link_to(
                delivery.shop_orders_count,
                shop_orders_path(
                  q: { _delivery_gid_eq: delivery.gid }, scope: :all_without_cart))
                  }
          end
        end
        panel t(".opening") do
          attributes_table do
            row(:open) { status_tag(delivery.shop_open?) }
            if delivery.shop_open?
              row(:open_until) { l(delivery.shop_closing_at, format: :medium) }
            end
            row(Depot.model_name.human(count: 2)) {
              display_depots(delivery.available_for_depots)
            }
          end
        end
        panel Shop::SpecialDelivery.human_attribute_name(:description) do
          div class: "p-2" do
            if delivery.shop_text?
              delivery.shop_text
            else
              div(class: "missing-data") { t("active_admin.empty") }
            end
          end
        end
        active_admin_comments_for(delivery)
      end
    end
  end

  action_item :xlsx, only: :show do
    link_to("XLSX", [ resource, format: :xlsx ], class: "action-item-button")
  end

  action_item :pdf, only: :show do
    link_to t(".delivery_orders_pdf"), delivery_shop_orders_path(delivery_gid: resource.gid, format: :pdf), target: "_blank", class: "action-item-button"
  end

  form do |f|
    f.inputs t(".details") do
      translated_input(f, :titles,
        required: false,
        placeholder: ->(locale) {
          I18n.with_locale(locale) { f.object.class.model_name.human }
        })
      f.input :date, as: :date_picker
      translated_input(f, :shop_texts,
        as: :action_text,
        required: false,
        hint: t("formtastic.hints.organization.shop_text"))
    end

    f.inputs t(".opening"), data: { controller: "form-checkbox-toggler" } do
      f.input :open,
        hint: t("formtastic.hints.delivery.shop_open"),
        input_html: { data: {
          form_checkbox_toggler_target: "checkbox",
          action: "form-checkbox-toggler#toggleInput"
        } }
      f.input :open_delay_in_days, hint: t("formtastic.hints.organization.shop_delivery_open_delay_in_days")
      f.input :open_last_day_end_time,
        as: :time_picker,
        hint: t("formtastic.hints.organization.shop_delivery_open_last_day_end_time"),
        input_html: {
          value: f.object.open_last_day_end_time&.strftime("%H:%M")
        }
      f.input :available_for_depot_ids,
        label: Depot.model_name.human(count: 2),
        as: :check_boxes,
        collection: admin_depots,
        input_html: {
          data: { form_checkbox_toggler_target: "input" }
        }
    end

    f.inputs Shop::SpecialDelivery.human_attribute_name(:products), id: "products" do
      Shop::Product
        .includes(:producer)
        .group_by(&:producer)
        .sort_by { |p, pp| p.name }
        .each do |producer, products|
          f.input :products,
            label: producer.name,
            as: :check_boxes,
            collection: products.map { |p|
              [ p.display_name, p.id ]
            },
            hint: t("formtastic.hints.shop/special_delivery.products")
        end
    end
    f.actions
  end

  permit_params \
    :date,
    :open_delay_in_days, :open_last_day_end_time,
    :open,
    *I18n.available_locales.map { |l| "title_#{l}" },
    *I18n.available_locales.map { |l| "shop_text_#{l}" },
    available_for_depot_ids: [],
    product_ids: []

  before_action only: :index do
    if params.dig(:q, :during_year).present? && params.dig(:q, :during_year).to_i < Current.fy_year
      params[:scope] ||= "all"
    end
  end

  controller do
    include TranslatedCSVFilename

    def apply_sorting(chain)
      params[:order] ||= "date_desc" if params[:scope] == "past"
      super
    end

    def show
      respond_to do |format|
        format.html
        format.xlsx do
          producer = Shop::Producer.find(params[:producer_id]) if params[:producer_id].present?
          xlsx = XLSX::Shop::Delivery.new(resource, producer)
          send_data xlsx.data,
            content_type: xlsx.content_type,
            filename: xlsx.filename
        end
      end
    end
  end

  config.sort_order = "date_asc"
end
