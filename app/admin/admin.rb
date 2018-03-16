ActiveAdmin.register Admin do
  menu parent: 'Autre', priority: 99

  index download_links: false do
    column :name
    column :email
    column :last_sign_in_at
    column :last_sign_in_ip
    column :rights
    actions
  end

  show do |admin|
    attributes_table do
      row :name
      row :email
      row :rights
      row :sign_in_count
      row :current_sign_in_at
      row :current_sign_in_ip
      row :last_sign_in_at
      row :last_sign_in_ip
      row :created_at
      row :updated_at
      row(:notifications) {
        admin.notifications.map { |n| t("admin.notifications.#{n}") }.join(', ')
      }
    end
  end

  form do |f|
    f.inputs 'Admin' do
      f.input :name
      f.input :email
    end
    f.inputs 'Mot de passe' do
      f.input :password, required: false
      f.input :password_confirmation
    end
    f.inputs do
      f.input :notifications,
        as: :check_boxes,
        collection: Admin::NOTIFICATIONS.map { |n| [t("admin.notifications.#{n}"), n] }
    end
    if current_admin.superadmin?
      f.inputs do
        f.input :rights, collection: Admin::RIGHTS, include_blank: false
      end
    end
    f.actions
  end

  permit_params do
    pp = %i[name email]
    pp += %i[password password_confirmation] if params[:admin]&.fetch(:password).present?
    pp << :rights if current_admin.superadmin?
    pp << { notifications: [] }
    pp
  end

  config.filters = false
end
