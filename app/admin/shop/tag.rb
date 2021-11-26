ActiveAdmin.register Shop::Tag do
  menu parent: :shop, priority: 10
  actions :all, except: [:show]

  breadcrumb do
    links = [t('active_admin.menu.shop')]
    unless params['action'] == 'index'
      links << link_to(Shop::Tag.model_name.human(count: 2), shop_tags_path)
    end
    links
  end

  includes :products

  index download_links: false do
    column :name, ->(tag) { link_to tag.display_name, [:edit, tag] }
    column :products, ->(tag) {
      link_to(
        tag.products.size,
        shop_products_path(
          q: { tags_id_eq: tag.id }))
    }
    actions class: 'col-actions-2'
  end

  form do |f|
    f.inputs t('.details') do
      f.input :emoji, input_html: { class: 'emoji-button', size: 1 }
      translated_input(f, :names)
    end
    f.actions
  end

  permit_params(
    :emoji,
    *I18n.available_locales.map { |l| "name_#{l}" })

  config.filters = false
  config.sort_order = "names_asc"
end
