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

  includes :products

  index download_links: false do
    column :name, ->(tag) { link_to tag.display_name, [ :edit, tag ] }
    column :products, ->(tag) {
      link_to(
        tag.products.size,
        shop_products_path(
          q: { tags_id_eq: tag.id }))
    }
    if authorized?(:update, Shop::Tag)
      actions class: "col-actions-2"
    end
  end

  form do |f|
    f.inputs t(".details") do
      translated_input(f, :names)
      f.input :emoji, input_html: { data: { controller: "emoji-button", emoji_button_target: "button", action: "click->emoji-button#toggle" }, class: "emoji-button", size: 1 }
    end
    f.actions
  end

  permit_params(
    :emoji,
    *I18n.available_locales.map { |l| "name_#{l}" })

  controller do
    def find_collection(*)
      super.kept
    end
  end

  config.filters = false
  config.sort_order = :default_scope
end
