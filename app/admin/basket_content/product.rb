# frozen_string_literal: true

class BasketContent
  ActiveAdmin.register Product do
    menu false
    actions :all, except: [ :show ]

    breadcrumb do
      links = [ link_to(BasketContent.model_name.human(count: 2), smart_basket_contents_path) ]
      if params[:action] != "index"
        links << link_to(Product.model_name.human(count: 2), basket_content_products_path)
      end
      if params["action"].in? %W[edit]
        links << resource.name
      end
      links
    end

    filter :name_cont,
      label: -> { BasketContent::Product.human_attribute_name(:name) },
      as: :string
    filter :unit, collection: -> { units_collection }, as: :select
    filter :default_price

    includes :basket_contents, latest_basket_content: :delivery
    index do
      column :name, ->(p) {
        display_with_external_url(p.name, p.url)
      }, sortable: true
      column(:unit) { |p| I18n.t("units.#{p.unit}.long") }
      column(:default_price, class: "text-right") { |p|
        if p.default_price.present?
          span class: "inline-flex items-baseline gap-x-1" do
            span cur(p.default_price, unit: false), class: "tabular-nums"
            span "/#{t("units.#{p.unit}.short")}", class: "text-gray-500 w-5 text-sm text-left"
          end
        end
      }
      column(:latest_use, class: "text-right tabular-nums") { |p|
        if p.latest_basket_content
          link_to(
            l(p.latest_basket_content.delivery.date, format: :number),
            basket_contents_path(q: { delivery_id_eq: p.latest_basket_content.delivery_id }))
        end
      }
      if authorized?(:update, Product)
        actions class: "col-actions-2"
      end
    end

    sidebar :info, only: :index do
      side_panel t(".info"), action: handbook_icon_link("basket_content", anchor: "products") do
        para t(".product_info")
      end
    end

    csv do
      column(:id)
      column(:name)
      column(:url)
      column(:latest_delivery) { |p|
        p.latest_basket_content&.delivery&.date
      }
      column(:latest_unit) { |p| t("units.#{p.unit}.flex") }
      column(:latest_quantity) { |p| p.latest_basket_content&.quantity }
      column(:latest_unit_price) { |p| p.latest_basket_content&.unit_price }
    end

    show do
      attributes_table do
        row :name
        row :url
      end
    end

    form do |f|
      f.inputs t(".details"), icon: "notebook-text" do
        translated_input(f, :names)
        f.input :url, hint: t("formtastic.hints.basket_content/product.url")
      end
      f.inputs t(".settings"), icon: "sliders-horizontal",
        data: {
          controller: "price-unit-suffix",
          "price-unit-suffix-suffixes-value" => { kg: "/#{t("units.kg.flex")}", pc: "/#{t("units.pc.flex")}" }.to_json
        } do
        f.input :unit,
          as: :select,
          collection: units_collection,
          prompt: true,
          include_blank: false,
          input_html: {
            data: {
              "price-unit-suffix-target" => "select",
              action: "price-unit-suffix#update"
            }
          }
        li class: "input number" do
          label BasketContent::Product.human_attribute_name(:default_price), for: "basket_content_product_default_price", class: "label"
          div class: "inline-flex items-baseline" do
            text_node helpers.tag.input(
              type: "number", min: 0, step: 0.01,
              id: "basket_content_product_default_price",
              name: "basket_content_product[default_price]",
              value: f.object.default_price)
            span "/#{t("units.#{f.object.unit || 'kg'}.flex")}",
              class: "text-sm text-gray-500 dark:text-gray-400 ms-2",
              data: { "price-unit-suffix-target" => "text" }
          end
          para t("formtastic.hints.basket_content/product.default_price"), class: "inline-hints"
        end
      end
      f.actions
    end

    permit_params(:url, :unit, :default_price, *I18n.available_locales.map { |l| "name_#{l}" })

    controller do
      include TranslatedCSVFilename
    end

    order_by(:name) do |clause|
      config
        .resource_class
        .order_by_name(clause.order)
        .order_values
        .join(" ")
    end

    config.sort_order = "name_asc"
  end
end
