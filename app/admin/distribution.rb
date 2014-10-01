ActiveAdmin.register Distribution do
  index do
    selectable_column
    id_column
    column :name
    actions
  end

  filter :name

  config.per_page = 50
end
