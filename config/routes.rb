Rails.application.routes.draw do
  constraints subdomain: 'admin' do
    devise_for :admins, ActiveAdmin::Devise.config

    get 'gribouille_emails' => 'gribouille_emails#index'
    get 'deliveries/next' => 'next_delivery#next'
    get 'halfday_works/calendar' => 'halfday_works_calendar#show'
    get 'settings' => 'acps#edit', as: :edit_acp
    get 'settings' => 'acps#edit', as: :acps
    get 'gribouilles/new' => 'gribouilles#new', as: :gribouilles
    get 'billing/:year' => 'billings#show', as: :billing

    resource :acp, path: 'settings', only: :update

    ActiveAdmin.routes(self)
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
