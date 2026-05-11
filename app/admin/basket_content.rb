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
      links << link_to(BasketContent.model_name.human(count: 2), basket_contents_path(q: { delivery_id_eq: resource.delivery_id }))
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
        basket_content_prices = delivery.basket_content_prices
        if basket_content_prices.any?
          panel t(".basket_prices", currency: currency_symbol) do
            render partial: "active_admin/basket_contents/prices", locals: { delivery: delivery, basket_content_prices: basket_content_prices, context: self }
          end
          return div class: "table-wrapper" do
            div class: "table-wrapper-content" do
              super
            end
          end
        end
      end
      super
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
    column :depots, ->(bc) { display_depots(bc.depots) }, class: "text-right"
    actions
  end

  action_item :product, only: :index do
    action_link BasketContent::Product.model_name.human(count: 2), basket_content_products_path, icon: "sprout"
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
        icon "sliders-horizontal", class: "size-5"
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
      && BasketContent.coming_deliveries_missing_contents_from(delivery).any?
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
      && (delivery = Delivery.find(params.dig(:q, :delivery_id_eq)))
      && BasketContent.filled_deliveries_with_contents_missing_from(delivery).any?
  } do
    side_panel t(".duplicate_all_from") do
      delivery = Delivery.find(params.dig(:q, :delivery_id_eq))
      render partial: "active_admin/basket_contents/duplicate_all_from",
        locals: { to_delivery: delivery }
    end
  end

  sidebar_handbook_link("basket_content")

  collection_action :form_prices, method: :get do
    delivery = Delivery.find_by(id: params[:delivery_id])

    render partial: "active_admin/basket_contents/form_prices",
      locals: BasketContent::FormPricePreview.new(delivery: delivery, params: params).to_h,
      layout: false
  end

  collection_action :duplicate_all, method: :post do
    authorize!(:create, BasketContent)
    from = params.require(:from_delivery_id)
    to = params.require(:to_delivery_id)
    BasketContent.duplicate_all(from, to)
    redirect_to basket_contents_path(q: { delivery_id_eq: to })
  end

  form do |f|
    div data: {
      controller: "basket-content-products-select basket-content-distribution",
      action: [
        "input->basket-content-distribution#formChanged",
        "change->basket-content-distribution#formChanged",
        "basket-content-products-updated->basket-content-distribution#productDefaultsChanged"
      ].join(" "),
      "basket-content-distribution-url-value" => form_prices_basket_contents_path,
      "basket-content-distribution-id-value" => f.object.persisted? ? f.object.id.to_s : "",
      "basket-content-distribution-pc-suffix-value" => t("units.pc_quantity", quantity: "").strip
    } do
      f.inputs t(".details"), icon: "notebook-text" do
        f.input :delivery,
          collection: grouped_by_date(Delivery, past: :first),
          required: true,
          prompt: true
      end
      f.inputs BasketContent.human_attribute_name(:content), icon: "sprout" do
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
      unit_suffix = basket_content_unit_suffix(f.object.unit)
      f.inputs t("basket_content.distribution"), icon: "scale" do
        f.semantic_errors :basket_quantities
        li class: "input string" do
          div class: "flex items-center gap-1 mb-1" do
            label BasketContent.human_attribute_name(:quantity), for: "basket_content_total_quantity", class: "label font-normal! m-0!"
            text_node tooltip("basket-content-total-quantity",
              t("basket_content.total_quantity_tooltip"), icon_class: "size-4 text-gray-600 dark:text-gray-400")
          end
          div class: "inline-flex items-center" do
            text_node helpers.tag.input(
              type: "number", min: 0,
              id: "basket_content_total_quantity",
              value: f.object.rounded_quantity.positive? ? f.object.rounded_quantity : nil,
              class: "text-input w-24",
              "data-basket-content-products-select-target" => "totalQuantityInput",
              "data-basket-content-distribution-target" => "totalQuantity",
              "data-action" => "input->basket-content-distribution#totalQuantityChanging blur->basket-content-distribution#totalQuantityChanged")
            span basket_content_total_unit_suffix(f.object.unit),
              class: "bc-total-unit-suffix text-sm text-gray-500 dark:text-gray-400 ms-2"
            span class: "bc-total-form-price empty:hidden"
          end
        end
        percentages = basket_content_form_percentages(f.object)
        BasketSize.ordered.paid.each do |basket_size|
          li class: "input bc-size-row mt-3 flex flex-wrap items-center gap-x-6 gap-y-1",
              data: {
                "basket-size-id" => basket_size.id,
                "baskets-count" => f.object.baskets_count(basket_size)
              } do
            label basket_size.name, for: "basket_size_ids_quantities_#{basket_size.id}", class: "label w-full m-0 p-0"
            div class: "flex w-full md:w-auto items-center justify-around gap-x-6" do
              div class: "relative w-full md:w-60" do
                text_node helpers.tag.input(
                  type: "range", min: 0, max: 100, step: 1,
                  disabled: f.object.quantity.to_f.zero?,
                  id: "basket_size_ids_percentages_#{basket_size.id}_range",
                  value: percentages[basket_size.id] || 0,
                  class: "w-full",
                  "data-basket-content-distribution-target" => "range",
                  "data-action" => "input->basket-content-distribution#percentageChanged")
                span class: "bc-percentage-label absolute -bottom-3.5 right-0 text-xs text-gray-400 dark:text-gray-500 tabular-nums",
                  "data-basket-content-distribution-target" => "percentageLabel" do
                  text_node "#{(percentages[basket_size.id] || 0).round}%"
                end
              end
              div class: "inline-flex items-center" do
                text_node helpers.tag.input(
                  type: "number", min: 0, step: 1,
                  id: "basket_size_ids_quantities_#{basket_size.id}",
                  name: "basket_content[basket_size_ids_quantities][#{basket_size.id}]",
                  value: f.object.basket_size_ids_quantity(basket_size),
                  class: "w-22 text-left",
                  "data-basket-content-distribution-target" => "quantityInput",
                  "data-action" => "input->basket-content-distribution#quantityChanging blur->basket-content-distribution#quantityChanged")
                span unit_suffix, class: "bc-unit-suffix text-sm text-gray-500 dark:text-gray-400 ms-2"
              end
            end
            span class: "bc-form-price empty:hidden w-full md:w-auto"
          end
        end
        li class: "input flex mt-4 mb-2 gap-2" do
          button class: "btn btn-light btn-sm",
              type: "button",
              "data-basket-content-distribution-target" => "preset",
              "data-action" => "basket-content-distribution#applyPreset",
              "data-preset" => f.object.basket_size_ids_percentages_pro_rated.to_json(stringify: true) do
            t("basket_content.preset.basket_content_percentages_pro_rated")
          end
          button class: "btn btn-light btn-sm",
              type: "button",
              "data-basket-content-distribution-target" => "preset",
              "data-action" => "basket-content-distribution#applyPreset",
              "data-preset" => f.object.basket_size_ids_percentages_even.to_json(stringify: true) do
            t("basket_content.preset.basket_content_percentages_even")
          end
        end
        f.input :depots,
          as: :check_boxes,
          wrapper_html: { class: "mt-6" },
          collection: admin_depots,
          grouped_collection: admin_depots_grouped_collection
      end
      render partial: "active_admin/basket_contents/form_prices",
        locals: { prices_data: {}, baskets_counts: {}, unit: nil }
      f.actions do
        f.action :submit
        cancel_link basket_contents_path(q: { delivery_id_eq: f.object.delivery_id })
      end
    end
  end

  permit_params(*%i[delivery_id product_id unit unit_price],
    depot_ids: [],
    basket_size_ids_quantities: {})

  before_build do |basket_content|
    basket_content.delivery_id ||= referer_filter(:delivery_id) || Delivery.next&.id
    if params[:action] == "new" && basket_content.depots.empty?
      basket_content.depots = Depot.kept
    end
  end

  before_action only: :index do
    params[:q] ||= {}
    if delivery_id = params.dig(:q, :delivery_id_eq)
      if delivery = Delivery.find_by(id: delivery_id)
        fy_year = params.dig(:q, :during_year)
        if fy_year && fy_year.to_i != delivery.fy_year
          params[:q][:delivery_id_eq] = BasketContent.closest_delivery(fy_year)&.id
        else
          params[:q][:during_year] = delivery.fy_year
        end
      end
    elsif fy_year = params.dig(:q, :during_year)
      params[:q][:delivery_id_eq] = BasketContent.closest_delivery(fy_year)&.id
    end
  end

  controller do
    include TranslatedCSVFilename
    include ApplicationHelper
    include UncachedSendData

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
