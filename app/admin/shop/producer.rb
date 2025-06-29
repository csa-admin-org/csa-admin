# frozen_string_literal: true

ActiveAdmin.register Shop::Producer do
  menu parent: :navshop, priority: 3
  actions :all, except: [ :show ]

  breadcrumb do
    if params["action"] == "index"
      [ t("active_admin.menu.shop") ]
    else
      links = [
        t("active_admin.menu.shop"),
        link_to(Shop::Producer.model_name.human(count: 2), shop_producers_path)
      ]
      if params["action"].in? %W[edit]
        links << resource.name
      end
      links
    end
  end

  filter :name_cont, label: -> { Shop::Producer.human_attribute_name(:name) }

  includes :products

  index download_links: false do
    column :name
    column :products, ->(producer) {
      link_to(
        producer.products.size,
        shop_products_path(
          q: { producer_id_eq: producer.id }))
    }, class: "text-right"
    actions
  end

  sidebar_shop_admin_only_warning
  sidebar_handbook_link("shop#producteurs")

  form do |f|
    f.inputs t(".details") do
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
