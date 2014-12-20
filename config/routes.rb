Rails.application.routes.draw do
  constraints subdomain: 'admin' do
    devise_for :admins, ActiveAdmin::Devise.config
    ActiveAdmin.routes(self)
    get 'halfday_works/calendar' => 'halfday_works_calendar#show'
  end

  scope module: 'members',  as: 'members' do
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
end
