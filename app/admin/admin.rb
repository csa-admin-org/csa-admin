ActiveAdmin.register Admin do
  menu false
  permit_params :email, :password, :password_confirmation

  form do |f|
    f.inputs 'Admin' do
      f.input :email
      f.input :password
      f.input :password_confirmation
    end
    f.actions
  end

  controller do
    def show
      redirect_to [:edit, resource]
    end
  end
end
