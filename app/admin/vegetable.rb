ActiveAdmin.register Vegetable do
  menu parent: 'Autre', priority: 10
  actions :all, except: [:show]

  index do
    column :name
    actions
  end

  show do |basket|
    attributes_table do
      row :name
    end
  end

  permit_params *%i[name]

  controller do
    def create
      super do |format|
        redirect_to collection_url and return if resource.valid?
      end
    end

    def update
      super do |format|
        redirect_to collection_url and return if resource.valid?
      end
    end
  end

  config.filters = false
  config.per_page = 50
end
