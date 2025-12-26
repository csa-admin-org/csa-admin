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

    includes :basket_contents, latest_basket_content: :delivery
    index do
      column :name, sortable: true
      column :url, ->(p) { link_to(p.url_domain, p.url) if p.url? }
      column(:default_price) { |p|
        if p.default_unit.present?
          t("units.#{p.default_unit}_quantity", quantity: "#{cur(p.default_unit_price)}/")
        end
      }
      column(:latest_use) { |p|
        if p.latest_basket_content
          display_with_unit_price(p.latest_basket_content.unit_price, p.latest_basket_content.unit) {
            link_to(
              l(p.latest_basket_content.delivery.date),
              basket_contents_path(q: { delivery_id_eq: p.latest_basket_content.delivery_id }))
          }
        end
      }
      if authorized?(:update, Product)
        actions class: "col-actions-2"
      end
    end

    csv do
      column(:id)
      column(:name)
      column(:url)
      column(:latest_delivery) { |p|
        p.latest_basket_content&.delivery&.date
      }
      column(:latest_unit) { |p|
        if p.latest_basket_content
          t("units.#{p.latest_basket_content.unit}")
        end
      }
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
      f.inputs t(".details") do
        translated_input(f, :names)
        f.input :url, hint: t("formtastic.hints.basket_content/product.url")
      end
      f.inputs t(".defaults") do
        para t("formtastic.hints.basket_content/product.defaults_intro"), class: "description -mt-2 mb-4"
        div class: "single-line" do
          f.input :default_unit,
            as: :select,
            collection: units_collection,
            include_blank: true
          f.input :default_unit_price,
            hint: t("formtastic.hints.basket_content.unit_price")
        end
      end
      f.actions
    end

    permit_params(:url, :default_unit, :default_unit_price, *I18n.available_locales.map { |l| "name_#{l}" })

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
