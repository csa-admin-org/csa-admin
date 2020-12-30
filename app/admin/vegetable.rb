ActiveAdmin.register Vegetable do
  menu parent: :other, priority: 10
  actions :all, except: [:show]

  index do
    column :name
    actions class: 'col-actions-2'
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

  permit_params(names: I18n.available_locales)

  controller do
    include TranslatedCSVFilename
  end

  config.filters = false
  config.per_page = 50
  config.sort_order = -> { "names->>'#{I18n.locale}'" }
end
