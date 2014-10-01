ActiveAdmin.register Member do
  # See permitted parameters documentation:
  # https://github.com/gregbell/active_admin/blob/master/docs/2-resource-customization.md#setting-up-strong-parameters
  #
  # permit_params :list, :of, :attributes, :on, :model
  #
  # or
  #
  # permit_params do
  #  permitted = [:permitted, :attributes]
  #  permitted << :other if resource.something?
  #  permitted
  # end
  index do
    selectable_column
    # id_column
    column :name
    column :emails
    column :phones
    column :distribution, sortable: :distribution_id
    actions
  end

  filter :name
  filter :emails
  filter :address
  filter :distribution
  filter :zip, as: :select, collection: -> { Member.pluck(:zip).uniq.compact.sort }
  filter :created_at

  config.per_page = 150
end
