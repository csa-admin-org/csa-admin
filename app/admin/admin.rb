ActiveAdmin.register Admin do
  menu false

  index download_links: false do
    column :email
    column :last_sign_in_at
    column :last_sign_in_ip
    column :rights
    actions
  end

  show do |admin|
    attributes_table do
      row :email
      row :rights
      row :sign_in_count
      row :current_sign_in_at
      row :current_sign_in_ip
      row :last_sign_in_at
      row :last_sign_in_ip
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.inputs 'Admin' do
      f.input :email
      if current_admin.superadmin?
        f.input :rights, collection: Admin::RIGHTS, include_blank: false
      else
        f.input :password
        f.input :password_confirmation
      end
    end
    f.actions
  end

  permit_params do
    params = %i[email password password_confirmation]
    params << :rights if current_admin.superadmin?
    params
  end

  config.filters = false
end
