ActiveAdmin.register Vegetable do
  menu parent: :other, priority: 10
  actions :all, except: [:show]

  index do
    column :name
    actions
  end

  show do
    attributes_table do
      row :name
    end
  end

  permit_params(:name)

  config.filters = false
  config.per_page = 50
end
