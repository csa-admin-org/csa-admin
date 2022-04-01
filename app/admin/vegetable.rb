ActiveAdmin.register Vegetable do
  menu false
  actions :all, except: [:show]

  breadcrumb do
    links = [link_to(BasketContent.model_name.human(count: 2), basket_contents_path)]
    if params[:action] != 'index'
      links << link_to(Vegetable.model_name.human(count: 2), vegetables_path)
    end
    if params['action'].in? %W[edit]
      links << resource.name
    end
    links
  end

  includes :basket_contents
  index do
    column :name
    if authorized?(:update, Vegetable)
      actions class: 'col-actions-2'
    end
  end

  show do
    attributes_table do
      row :name
    end
  end

  form do |f|
    f.inputs do
      translated_input(f, :names)
    end
    f.actions
  end

  permit_params(*I18n.available_locales.map { |l| "name_#{l}" })

  controller do
    include TranslatedCSVFilename
  end

  config.filters = false
  config.per_page = 50
  config.sort_order = :default_scope
end
