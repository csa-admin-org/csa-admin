Rails.application.routes.draw do
  constraints subdomain: 'admin' do
    devise_for :admins, ActiveAdmin::Devise.config

    get 'deliveries/next' => 'next_delivery#next'
    get 'activity_participations/calendar' => 'activity_participations_calendar#show',
      defaults: { format: :ics }
    get 'settings' => 'acps#edit', as: :edit_acp
    get 'settings' => 'acps#edit', as: :acps
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
      resources :sessions, only: %i[show create]
      get '/login' => 'sessions#new', as: :login
      delete '/logout' => 'sessions#destroy', as: :logout

      resources :activities, only: :index
      resources :activity_participations, only: %i[index create destroy]
      resources :absences, only: %i[index create destroy]
      get 'billing' => 'billing#index'
      resource :member, only: %i[new show create], path: '' do
        get 'welcome', on: :collection
      end

      get '/:token' => 'sessions#old_token', constraints: { token: /\w{10}/ }
    end
  end
end
