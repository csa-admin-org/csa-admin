ActiveAdmin.register GroupBuying::Producer do
  menu parent: :group_buying, priority: 2
  actions :all, except: [:show]

  filter :name

  includes :products

  index do
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
        input_html: { rows: 10 },
        required: false)
    end
    f.actions
  end

  permit_params(
    :name,
    :website_url,
    descriptions: I18n.available_locales)


  controller do
    include TranslatedCSVFilename
  end

  config.sort_order = 'name_asc'
end
