ActiveAdmin.register Distribution do
  menu parent: 'Autre', priority: 10

  index download_links: false do
    column :name
    column :address
    column :zip
    column :city
    column :price do |distribution|
      number_to_currency(distribution.price)
    end
    column :responsible_member
    actions
  end

  show do |distribution|
    attributes_table do
      row :name
      row :address
      row :zip
      row :city
      row(:price) { number_to_currency(distribution.price) }
      row :emails
      row :responsible_member
    end
  end

  form do |f|
    f.inputs do
      f.input :name
      f.input :price
    end

    f.inputs 'Adresse' do
      f.input :address
      f.input :city
      f.input :zip
    end

    f.inputs 'Contact' do
      f.input :emails
      f.input :responsible_member, collection: Member.order(:name)
    end

    f.actions
  end

  permit_params *%i[name price address zip city emails responsible_member_id]

  config.filters = false
  config.per_page = 25
end
