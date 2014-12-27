ActiveAdmin.register Admin do
  menu false

  index do
    column :email
    column :current_sign_in_at
    column :current_sign_in_ip
    column :last_sign_in_at
    column :last_sign_in_ip
    column :updated_at
    actions
  end

  form do |f|
    f.inputs 'Admin' do
      f.input :email
      f.input :password
      f.input :password_confirmation
    end
    f.actions
  end
  permit_params *%i[email password password_confirmation]

  controller do
    def show
      redirect_to [:edit, resource]
    end
  end

  config.filters = false
end
