Rails.application.routes.draw do
  scope module: 'members' do
    constraints subdomain: 'membres' do
      get '/' => redirect('/token/recover')
      resources :members, only: [:show], path: '' do
        resources :halfday_works
      end
      resource :member_token,
        path: 'token',
        only: [:edit],
        path_names: { edit: 'recover'} do
        post :recover, on: :member
      end
    end
  end

  constraints subdomain: 'admin' do
    devise_for :admins, ActiveAdmin::Devise.config
    ActiveAdmin.routes(self)
  end

end
