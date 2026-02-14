# frozen_string_literal: true

ActiveAdmin.register BasketContent do
  menu \
    priority: 5,
    label: -> {
      [
        icon("shopping-bag", class: "size-5 -mt-0.5 mr-2.5 md:mr-2 inline"),
        Basket.model_name.human(count: 2)
      ].join.html_safe
    },
    url: -> { smart_basket_contents_path }

  breadcrumb do
    links = []
    case params[:action]
    when "new"
      links << link_to(BasketContent.model_name.human(count: 2), smart_basket_contents_path)
    when "edit"
      links << link_to(BasketContent.model_name.human(count: 2), basket_contents_path(q: { delivery_id_eq: resource.delivery_id, during_year: resource.delivery.fy_year }))
    end
    links
  end

  actions :all, except: [ :show ]

  filter :during_year,
    as: :select,
    collection: -> { fiscal_years_collection }
  filter :delivery,
    as: :select,
    collection: -> { grouped_by_date(Delivery, past: :first) }
  filter :product, as: :select, collection: -> { BasketContent::Product.ordered }
  filter :basket_size, as: :select, collection: -> { BasketSize.ordered.paid }
  filter :depots, as: :select, collection: -> { admin_depots_collection }

  includes :depots, :delivery, :product, :basketcontents_depots

  class BasketContentIndex < ActiveAdmin::Views::IndexAsTable
    def build(_page_presenter, collection)
      if params.dig(:q, :delivery_id_eq).present? && collection.with_unit_price.any?
        delivery = Delivery.find(params.dig(:q, :delivery_id_eq))
        panel t(".basket_prices", currency: currency_symbol) do
          render partial: "active_admin/basket_contents/prices", locals: { delivery: delivery, context: self }
        end
      end
      div class: "table-wrapper" do
        div class: "table-wrapper-content" do
          super
        end
      end
    end
  end

  index as: BasketContentIndex, download_links: -> {
    params.dig(:q, :delivery_id_eq).present? ? [ :csv, :xlsx ] : [ :csv ]
  }, title: -> {
    title = BasketContent.model_name.human(count: 2)
    if params.dig(:q, :delivery_id_eq).present?
      delivery = Delivery.find(params.dig(:q, :delivery_id_eq))
      title += " – #{delivery.display_name}"
    end
    title
  } do
    unless params.dig(:q, :delivery_id_eq).present?
      column :delivery, ->(bc) { I18n.l bc.delivery.date, format: :number }, class: "whitespace-nowrap", sortable: :delivery_date
    end
    column :product, ->(bc) {
      display_with_unit_price(bc.unit_price, bc.unit) {
        display_with_external_url(bc.product.name, bc.product.url)
      }
    }, class: "whitespace-nowrap", sortable: :product_name
    unless params.dig(:q, :basket_size_eq).present?
      column :qt, ->(bc) {
        display_with_price(bc.unit_price, bc.quantity) {
          display_quantity(bc.quantity, bc.unit)
        }
      }, class: "text-right whitespace-nowrap"
    end
    basket_sizes = if params.dig(:q, :basket_size_eq).present?
      BasketSize.ordered.where(id: params.dig(:q, :basket_size_eq))
    else
      BasketSize.ordered.paid
    end
    basket_sizes.each do |basket_size|
      column basket_size.name, ->(bc) {
        display_with_price(bc.unit_price, bc.basket_quantity(basket_size)) {
          display_basket_quantity(bc, basket_size)
        }
      }, class: "text-right whitespace-nowrap"
    end
    unless params.dig(:q, :basket_size_eq).present?
      column :surplus, ->(bc) {
        display_with_price(bc.unit_price, bc.surplus_quantity) {
          display_surplus_quantity(bc)
        }
      }, class: "text-right whitespace-nowrap"
    end
    column :depots, ->(bc) { display_depots(bc.depots) }
    actions
  end

  action_item :product, only: :index do
    action_link BasketContent::Product.model_name.human(count: 2), basket_content_products_path
  end

  csv do
    column(:date) { |bc| bc.delivery.date.to_s }
    column(:month) { |bc| t("date.month_names")[bc.delivery.date.month] }
    column(:wday) { |bc| t("date.day_names")[bc.delivery.date.wday] }
    column(:product) { |bc| bc.product.name }
    column(:unit) { |bc| t("units.#{bc.unit}") }
    column(:unit_price) { |bc| cur(bc.unit_price) }
    column(:quantity) { |bc| bc.quantity }
    BasketSize.paid.ordered.each do |basket_size|
      column("#{basket_size.name} - #{Basket.model_name.human(count: 2)}") { |bc|
        bc.baskets_count(basket_size)
      }
      column("#{basket_size.name} - #{t("attributes.quantity")}") { |bc|
        bc.basket_quantity(basket_size)
      }
      column("#{basket_size.name} - #{BasketContent.human_attribute_name(:price)}") { |bc|
        display_price bc.unit_price, bc.basket_quantity(basket_size)
      }
    end
    column(:surplus) { |bc| bc.surplus_quantity }
    column("#{BasketContent.human_attribute_name(:surplus)} - #{BasketContent.human_attribute_name(:price)}") { |bc|
      display_price bc.unit_price, bc.surplus_quantity
    }
    column(:depots) { |bc| display_depots(bc.depots) }
  end

  sidebar :member_visibility, only: :index, if: -> {
    params.dig(:q, :delivery_id_eq).present? &&
      Delivery.find(params.dig(:q, :delivery_id_eq)).coming?
  } do
    t_scope = "active_admin.basket_contents.member_visibility"
    delivery = Delivery.find(params.dig(:q, :delivery_id_eq))

    settings_action = if authorized?(:update, Organization)
      link_to edit_organization_path(anchor: "basket_content"), title: t("#{t_scope}.settings") do
        icon "adjustments-horizontal", class: "size-6 mt-0.5"
      end
    end

    if Current.org.basket_content_member_visible?
      side_panel t(".member_visibility"), action: settings_action do
        if Current.org.basket_content_visible_for_delivery?(delivery)
          para t("#{t_scope}.currently_visible")
        else
          visible_at = Current.org.basket_content_member_visible_at(delivery)
          para t("#{t_scope}.visible_on_html", datetime: I18n.l(visible_at, format: :short))
        end
      end
    else
      side_panel t(".member_visibility"), action: settings_action do
        para t("#{t_scope}.disabled"), class: "text-sm text-gray-500"
      end
    end
  end

  sidebar :duplicate_all_to, only: :index, if: -> {
    authorized?(:create, BasketContent)
      && params.dig(:q, :delivery_id_eq).present?
      && collection.present?
      && (delivery = Delivery.find(params.dig(:q, :delivery_id_eq)))
      && BasketContent.coming_unfilled_deliveries(after_date: delivery.date).any?
  } do
    side_panel t(".duplicate_all_to") do
      delivery = Delivery.find(params.dig(:q, :delivery_id_eq))
      render partial: "active_admin/basket_contents/duplicate_all_to",
        locals: { from_delivery: delivery }
    end
  end

  sidebar :duplicate_all_from, only: :index, if: -> {
    authorized?(:create, BasketContent)
      && params.dig(:q, :delivery_id_eq).present?
      && collection.empty?
      && BasketContent.any?
  } do
    side_panel t(".duplicate_all_from") do
      delivery = Delivery.find(params.dig(:q, :delivery_id_eq))
      render partial: "active_admin/basket_contents/duplicate_all_from",
        locals: { to_delivery: delivery }
    end
  end

  sidebar_handbook_link("basket_content")

  collection_action :duplicate_all, method: :post do
    authorize!(:create, BasketContent)
    from = params.require(:from_delivery_id)
    to = params.require(:to_delivery_id)
    BasketContent.duplicate_all(from, to)
    redirect_to basket_contents_path(q: { delivery_id_eq: to })
  end

  form data: { controller: "basket-content-products-select" } do |f|
    f.inputs t(".details") do
      f.input :delivery,
        collection: grouped_by_date(Delivery, past: :first),
        required: true,
        prompt: true
    end
    f.inputs BasketContent.human_attribute_name(:content) do
      f.input :product,
        input_html: {
          data: {
            action: "basket-content-products-select#productChange form-hint-url#change",
            "basket-content-products-select-target" => "productSelect"
          }
        },
        wrapper_html: {
          data: {
            controller: "form-hint-url"
          }
        },
        collection: basket_content_products_collection,
        required: true,
        prompt: true,
        hint: link_to(f.object.product&.url_domain.to_s, f.object.product&.url, target: "_blank", data: { "form-hint-url-target" => "link" })
      f.input :unit,
        collection: units_collection,
        prompt: true,
        input_html: {
          data: {
            action: "basket-content-products-select#unitChange",
            "basket-content-products-select-target" => "unitSelect"
          }
        }
      f.input :unit_price,
        label: BasketContent.human_attribute_name(:price),
        as: :number,
        min: 0,
        step: 0.01,
        input_html: {
          data: {
            "basket-content-products-select-target" => "unitPriceInput"
          }
        }
    end
    div "data-controller" => "basket-content-distribution" do
      h2 t("basket_content.distribution"), class: "text-2xl font-extralight mb-2"
      f.input :distribution_mode,
        as: :hidden,
        input_html: {
          data: {
            "basket-content-distribution-target" => "mode"
          }
        }
      f.inputs do
        tabs do
          tab t("basket_content.distribution_mode.automatic"), id: "automatic", selected: f.object.distribution_automatic?, html_options: { "data-action" => "click->basket-content-distribution#automaticMode" } do
            f.semantic_errors :basket_percentages
            f.input :quantity,
              input_html: {
                required: f.object.distribution_automatic?,
                disabled: !f.object.distribution_automatic?,
                data: {
                  "basket-content-products-select-target" => "quantityInput",
                  "basket-content-distribution-target" => "quantity"
                }
              }
            BasketSize.ordered.paid.each do |basket_size|
              f.input :basket_size_ids_percentages,
                as: :custom_range,
                step: 1,
                min: 0,
                max: 100,
                label: basket_size.name,
                required: true,
                wrapper_html: {
                  id: nil,
                  class: "flex flex-wrap items-center space-y-0 gap-x-3"
                },
                label_html: {
                  class: "w-full m-0 p-0"
                },
                hint: "%",
                input_html: {
                  id: "basket_size_ids_percentages_#{basket_size.id}",
                  value: f.object.basket_percentage(basket_size),
                  name: "basket_content[basket_size_ids_percentages][#{basket_size.id}]",
                  class: "w-14 text-right",
                  data: {
                    "basket-content-distribution-target" => "input",
                    "action" => "blur->basket-content-distribution#change"
                  }
                },
                range_html: {
                  id: "basket_size_ids_percentages_#{basket_size.id}_range",
                  name: "basket_content[basket_size_ids_percentages_range][#{basket_size.id}]",
                  class: "w-60",
                  data: {
                    "basket-content-distribution-target" => "range",
                    "action" => "basket-content-distribution#change"
                  }
                }
            end
            span class: "ms-5 w-72 mt-2 text-right text-base text-red-500 font-bold after:content-['%']",
              style: "display: none;",
              "data-basket-content-distribution-target" => "sum"
            div class: "flex mt-6 mb-2 gap-2" do
              button class: "btn btn-light btn-sm",
                  type: "reset",
                  "data-basket-content-distribution-target" => "preset",
                  "data-action" => "basket-content-distribution#applyPreset",
                  "data-preset" => f.object.basket_size_ids_percentages_pro_rated.to_json(stringify: true) do
                t("basket_content.preset.basket_content_percentages_pro_rated")
              end
              button class: "btn btn-light btn-sm",
                  type: "reset",
                  "data-basket-content-distribution-target" => "preset",
                  "data-action" => "basket-content-distribution#applyPreset",
                  "data-preset" => f.object.basket_size_ids_percentages_even.to_json(stringify: true) do
                t("basket_content.preset.basket_content_percentages_even")
              end
            end
            para class: "basket_content_distribution_wrapper_hint inline-hints" do
              t("basket_content.percentages_hint")
            end
          end
          tab t("basket_content.distribution_mode.manual"), id: "manual", selected: f.object.distribution_manual?, html_options: { "data-action" => "click->basket-content-distribution#manualMode" } do
            f.semantic_errors :basket_quantities

              para class: "description" do
                t("basket_content.quantities_hint")
              end

            BasketSize.ordered.paid.each do |basket_size|
              f.input :basket_size_ids_quantities,
                as: :number,
                step: 1,
                min: 0,
                label: basket_size.name,
                wrapper_html: { id: nil },
                input_html: {
                  required: f.object.distribution_manual?,
                  disabled: !f.object.distribution_manual?,
                  id: "basket_size_ids_quantities_#{basket_size.id}",
                  value: f.object.basket_size_ids_quantity(basket_size),
                  name: "basket_content[basket_size_ids_quantities][#{basket_size.id}]",
                  data: {
                    "basket-content-distribution-target" => "basketQuantity"
                  }
                }
            end
          end
        end
      end
    end
    f.inputs do
      f.input :depots,
        as: :check_boxes,
        wrapper_html: { class: "legend-title" },
        collection: admin_depots
    end
    f.actions do
      f.action :submit, as: :input
      cancel_link basket_contents_path(q: { delivery_id_eq: f.object.delivery_id, during_year: f.object.delivery&.fy_year })
    end
  end

  permit_params(*%i[delivery_id product_id quantity unit unit_price distribution_mode],
    depot_ids: [],
    basket_size_ids_percentages: {},
    basket_size_ids_quantities: {})

  before_build do |basket_content|
    basket_content.delivery_id ||= referer_filter(:delivery_id) || Delivery.next&.id
    if params[:action] == "new" && basket_content.depots.empty?
      basket_content.depots = Depot.kept
    end
  end

  controller do
    include TranslatedCSVFilename
    include ApplicationHelper

    def index
      super do |format|
        format.xlsx do
          delivery = Delivery.find(params.dig(:q, :delivery_id_eq))
          xlsx = XLSX::BasketContent.new(delivery)
          send_data xlsx.data,
            content_type: xlsx.content_type,
            filename: xlsx.filename
        end
      end
    end

    def create
      create! do |success, failure|
        success.html { redirect_to collection_path(q: { delivery_id_eq: resource.delivery_id, during_year: resource.delivery.fy_year }) }
      end
    end

    def update
      update! do |success, failure|
        success.html { redirect_to collection_path(q: { delivery_id_eq: resource.delivery_id, during_year: resource.delivery.fy_year }) }
      end
    end

    def scoped_collection
      super.joins(:delivery, :product)
    end
  end

  order_by(:product_name) do |clause|
    BasketContent::Product
      .order_by_name(clause.order)
      .order_values
      .join(" ")
  end

  order_by(:delivery_date) do |clause|
    Delivery
      .reorder(date: clause.order)
      .order_values
      .map(&:to_sql)
      .join(" ")
  end

  config.sort_order = "product_name_asc"
end
