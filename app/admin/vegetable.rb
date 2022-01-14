ActiveAdmin.register Vegetable do
  menu parent: :other, priority: 6
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

  permit_params(*I18n.available_locales.map { |l| "name_#{l}" })

  controller do
    include TranslatedCSVFilename
  end

  config.filters = false
  config.per_page = 50
  config.sort_order = :default_scope
end
