ActiveAdmin.register GroupBuying::Producer do
  menu parent: :group_buying, priority: 3
  actions :all, except: [:show]

  breadcrumb do
    if params['action'] == 'index'
      [t('active_admin.menu.group_buying')]
    else
      links = [
        t('active_admin.menu.group_buying'),
        link_to(GroupBuying::Producer.model_name.human(count: 2), group_buying_producers_path)
      ]
      if params['action'].in? %W[edit]
        links << group_buying_producer.name
      end
      links
    end
  end

  filter :name

  includes :products

  index download_links: false do
    column :name, ->(producer) { auto_link producer }
    column :products, ->(producer) {
      link_to(
        producer.products.size,
        group_buying_products_path(
          q: { producer_id_eq: producer.id }))
    }
    actions
  end

  form do |f|
    f.inputs t('.details') do
      f.input :name
      f.input :website_url
    end
    f.inputs do
      translated_input(f, :descriptions,
        as: :action_text,
        required: false)
    end
    f.actions
  end

  permit_params(
    :name,
    :website_url,
    descriptions: I18n.available_locales)

  config.sort_order = 'name_asc'
end
