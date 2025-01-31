# frozen_string_literal: true

ActiveAdmin.register BasketContent do
  menu priority: 5
  actions :all, except: [ :show ]

  filter :delivery, as: :select
  filter :during_year,
    as: :select,
    collection: -> { fiscal_years_collection }
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
    link_to BasketContent::Product.model_name.human(count: 2), basket_content_products_path, class: "action-item-button"
  end

  csv do
    column(:date) { |bc| bc.delivery.date.to_s }
    column(:month) { |bc| I18n.t("date.month_names")[bc.delivery.date.month] }
    column(:wday) { |bc| I18n.t("date.day_names")[bc.delivery.date.wday] }
    column(:product) { |bc| bc.product.name }
    column(:unit) { |bc| t("units.#{bc.unit}") }
    column(:unit_price) { |bc| cur(bc.unit_price) }
    column(:quantity) { |bc| bc.quantity }
    BasketSize.paid.ordered.each do |basket_size|
      column("#{basket_size.name} - #{Basket.model_name.human(count: 2)}") { |bc|
        bc.baskets_count(basket_size)
      }
      column("#{basket_size.name} - #{BasketContent.human_attribute_name(:quantity)}") { |bc|
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

  sidebar :duplicate_all_to, only: :index, if: -> {
    authorized?(:create, BasketContent) &&
      params.dig(:q, :delivery_id_eq).present? &&
      collection.present? &&
      (delivery = Delivery.find(params.dig(:q, :delivery_id_eq))) &&
      BasketContent.coming_unfilled_deliveries(after_date: delivery.date).any?
  } do
    side_panel t(".duplicate_all_to") do
      delivery = Delivery.find(params.dig(:q, :delivery_id_eq))
      render partial: "active_admin/basket_contents/duplicate_all_to",
        locals: { from_delivery: delivery }
    end
  end

  sidebar :duplicate_all_from, only: :index, if: -> {
    authorized?(:create, BasketContent) &&
      params.dig(:q, :delivery_id_eq).present? &&
      collection.empty? &&
      BasketContent.any?
  } do
    side_panel t(".duplicate_all_from") do
      delivery = Delivery.find(params.dig(:q, :delivery_id_eq))
      render partial: "active_admin/basket_contents/duplicate_all_from",
        locals: { to_delivery: delivery }
    end
  end

  collection_action :duplicate_all, method: :post do
    authorize!(:create, BasketContent)
    from = params.require(:from_delivery_id)
    to = params.require(:to_delivery_id)
    BasketContent.duplicate_all(from, to)
    redirect_to basket_contents_path(q: { delivery_id_eq: to })
  end

  form do |f|
    div class: "mb-6" do
      f.object.errors.attribute_names.each do |attr|
        para f.semantic_errors attr
      end
    end

    f.inputs t(".details") do
      f.input :delivery,
        collection: Delivery.all,
        required: true,
        prompt: true
    end
    f.inputs BasketContent.human_attribute_name(:content), "data-controller" => "basket-content-products-select" do
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
      f.input :quantity,
        input_html: {
          data: {
            "basket-content-products-select-target" => "quantityInput"
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
      f.inputs do
        tabs do
          tab t("basket_content.distribution_mode.automatic"), id: "automatic", selected: f.object.distribution_automatic?, html_options: { "data-action" => "click->basket-content-distribution#automaticMode" } do
            f.semantic_errors :basket_percentages
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
                  class: "flex flex-wrap items-center space-y-0 gap-2"
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
              a class: "action-item-button small",
                  "data-basket-content-distribution-target" => "preset",
                  "data-action" => "basket-content-distribution#applyPreset",
                  "data-preset" => f.object.basket_size_ids_percentages_pro_rated.to_json do
                t("basket_content.preset.basket_content_percentages_pro_rated")
              end
              a class: "action-item-button small",
                  "data-basket-content-distribution-target" => "preset",
                  "data-action" => "basket-content-distribution#applyPreset",
                  "data-preset" => f.object.basket_size_ids_percentages_even.to_json do
                t("basket_content.preset.basket_content_percentages_even")
              end
            end
            para class: "basket_content_distribution_wrapper_hint inline-hints" do
              t("basket_content.percentages_hint")
            end
          end
          tab t("basket_content.distribution_mode.manual"), id: "manual", selected: f.object.distribution_manual?, html_options: { "data-action" => "click->basket-content-distribution#manualMode" } do
            f.semantic_errors :basket_quantities
            BasketSize.ordered.paid.each do |basket_size|
              f.input :basket_size_ids_quantities,
                as: :number,
                step: 1,
                min: 0,
                label: basket_size.name,
                wrapper_html: { id: nil },
                input_html: {
                  id: "basket_size_ids_quantities_#{basket_size.id}",
                  value: f.object.basket_size_ids_quantity(basket_size),
                  name: "basket_content[basket_size_ids_quantities][#{basket_size.id}]",
                  data: {
                    "basket-content-distribution-target" => "quantityInput"
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
        collection: admin_depots_collection
    end
    f.actions
  end

  permit_params(*%i[delivery_id product_id quantity unit unit_price],
    depot_ids: [],
    basket_size_ids_percentages: {},
    basket_size_ids_quantities: {})

  before_action only: :index do
    if params.except(:subdomain, :controller, :action).empty? &&
        params[:q].blank? &&
        (delivery = BasketContent.last_delivery || Delivery.next || Delivery.last)
      redirect_to q: { delivery_id_eq: delivery.id }, utf8: "✓"
    end
  end

  before_build do |basket_content|
    basket_content.delivery_id ||= referer_filter(:delivery_id) || Delivery.next&.id
    if basket_content.depots.empty?
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
        success.html { redirect_to collection_path(q: { delivery_id_eq: resource.delivery_id }) }
      end
    end

    def update
      update! do |success, failure|
        success.html { redirect_to collection_path(q: { delivery_id_eq: resource.delivery_id }) }
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
