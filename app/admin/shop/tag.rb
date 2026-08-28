# frozen_string_literal: true

ActiveAdmin.register Shop::Tag do
  menu false
  actions :all, except: [ :show ]

  breadcrumb do
    links = [
      t("active_admin.menu.shop"),
      link_to(Shop::Product.model_name.human(count: 2), shop_products_path)
    ]
    unless params["action"] == "index"
      links << link_to(Shop::Tag.model_name.human(count: 2), shop_tags_path)
    end
    links
  end

  sidebar :info, only: :index do
    side_panel t(".info"), action: handbook_icon_link("shop", anchor: "tags") do
      para t(".shop_tag_info")
    end
  end

  includes :products

  index download_links: false do
    column :name, ->(tag) { link_to tag.display_name, [ :edit, tag ] }, sortable: true
    column :products, ->(tag) {
      link_to(
        tag.products.size,
        shop_products_path(
          q: { tags_id_eq: tag.id }))
    }, class: "text-right"
    actions
  end

  form do |f|
    f.inputs t(".details"), icon: "notebook-text" do
      div class: "single-line shop-tag-fields" do
        render partial: "shared/shop_tag_emoji", locals: { shop_tag: f.object }
        div class: "is-grow" do
          translated_input(f, :names)
        end
      end
    end
    f.actions
  end

  permit_params(
    :emoji,
    *I18n.available_locales.map { |l| "name_#{l}" })

  controller do
    def scoped_collection
      super.kept
    end
  end

  order_by(:name) do |clause|
    config
      .resource_class
      .order_by_name(clause.order)
      .order_values
      .join(" ")
  end

  config.filters = false
  config.sort_order = "name_asc"
end
