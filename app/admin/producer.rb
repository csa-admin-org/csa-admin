# frozen_string_literal: true

ActiveAdmin.register Producer do
  menu parent: :other, if: -> { feature?("shop") || feature?("basket_content") }
  actions :all, except: [ :show ]

  breadcrumb do
    next [] if params["action"] == "index"

    links = [ link_to(Producer.model_name.human(count: 2), producers_path) ]
    links << resource.name if params["action"].in?(%w[edit])
    links
  end

  filter :name_cont, label: -> { Producer.human_attribute_name(:name) }

  includes :shop_products, :basket_content_products
  index download_links: false do
    column :name
    if feature?("basket_content")
      column BasketContent.model_name.human, ->(producer) {
        link_to(
          producer.basket_content_products.size,
          basket_content_products_path(q: { producer_id_eq: producer.id }))
      }, class: "text-right"
    end
    if feature?("shop")
      column t("shop.title"), ->(producer) {
        link_to(
          producer.shop_products.size,
          shop_products_path(q: { producer_id_eq: producer.id }))
      }, class: "text-right"
    end
    actions
  end

  sidebar :info, only: :index do
    side_panel t(".info"), action: handbook_icon_link("shop", anchor: "producers") do
      para t(".producer_info")
    end
  end

  form do |f|
    f.inputs t(".details"), icon: "notebook-text" do
      f.input :name
      f.input :website_url
      translated_input(f, :descriptions,
        as: :action_text,
        required: false)
    end
    f.actions
  end

  permit_params(
    :name,
    :website_url,
    *I18n.available_locales.map { |l| "description_#{l}" })

  controller do
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
end
