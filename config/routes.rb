Rails.application.routes.draw do
  constraints subdomain: 'admin' do
    get 'gribouille_emails' => 'gribouille_emails#index'
    get 'deliveries/next' => 'next_delivery#next'
    get 'halfday_works/calendar' => 'halfday_works_calendar#show'
  end

  constraints subdomain: 'admin' do
    devise_for :admins, ActiveAdmin::Devise.config

    get '/settings' => 'acps#edit', as: :edit_acp
    get '/settings' => 'acps#edit', as: :acps
    resource :acp, path: 'settings', only: :update
    ActiveAdmin.routes(self)
    resource :billing, only: [:show]
  end

  scope module: 'stats', as: nil do
    constraints subdomain: 'stats' do
      get '/' => redirect('/members')
      resources :stats, only: [:show], path: '', constraints: {
        id: /(#{Stats::TYPES.join('|')})/
      }
    end
  end

  scope module: 'members', as: 'members' do
    constraints subdomain: 'membres' do
      get '/' => redirect('/token/recover')
      resources :members, only: [:show], path: '' do
        resources :halfday_participations
      end
      resource :member_token,
        path: 'token',
        only: [:edit],
        path_names: { edit: 'recover' } do
        post :recover, on: :member
      end
    end
  end
end
