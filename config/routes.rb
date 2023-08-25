require 'sidekiq/web'
require 'sidekiq-scheduler/web'

Rails.application.routes.draw do
  get '/health/ready', to: proc { [200, {}, ['ok']] }

  constraints subdomain: 'sidekiq' do
    Sidekiq::Web.use Rack::Auth::Basic do |username, password|
      ActiveSupport::SecurityUtils.secure_compare(::Digest::SHA256.hexdigest(username), ::Digest::SHA256.hexdigest('sidekiq')) &&
        ActiveSupport::SecurityUtils.secure_compare(::Digest::SHA256.hexdigest(password), ::Digest::SHA256.hexdigest(ENV["SIDEKIQ_WEB_PASSWORD"]))
    end if Rails.env.production?
    mount Sidekiq::Web, at: '/'
  end

  constraints subdomain: 'admin' do
    resources :sessions, only: %i[show create]
    get '/login' => 'sessions#new', as: :login
    delete '/logout' => 'sessions#destroy', as: :logout

    resources :email_suppressions, only: :destroy

    get 'activity_participations/calendar' => 'activity_participations_calendar#show',
      defaults: { format: :ics }
    get 'billing/:year' => 'billings#show', as: :billing
    get 'billing/snapshots/:id' => 'billing_snapshots#show', as: :billing_snapshot

    get 'settings' => 'acps#edit', as: :edit_acp
    get 'settings' => 'acps#edit', as: :acps
    resource :acp, path: 'settings', only: :update

    get 'deliveries/next' => 'next_delivery#next'
    get 'handbook/:id' => 'handbook#index', as: :handbook_page

    ActiveAdmin.routes(self)

    namespace :api do
      namespace :v1 do
        resource :configuration, only: :show
        get 'basket_contents/current' => 'basket_contents#index'
      end
    end
  end

  scope module: 'members', as: 'members' do
    constraints subdomain: %w[membres mitglieder soci] do
      resources :sessions, only: %i[show create]
      get '/login' => 'sessions#new', as: :login
      delete '/logout' => 'sessions#destroy', as: :logout

      get '/newsletters/unsubscribe/:token' => 'newsletter_subscriptions#destroy', as: 'unsubscribe_newsletter'
      post '/newsletters/subscribe/:token' => 'newsletter_subscriptions#create', as: 'subscribe_newsletter'

      get '/membership', to: redirect('/memberships')
      resources :memberships, only: %i[index edit update]
      resources :baskets, only: %i[edit update]

      scope :membership do
        resource :renewal,
          only: %i[new create],
          as: 'membership_renewal',
          controller: 'membership_renewals'
        get ':decision' => 'membership_renewals#new'
      end

      resources :deliveries, only: :index
      resources :activities, only: :index
      resources :activity_participations, only: %i[index create destroy]
      namespace :shop do
        get '/' => 'products#index'
        get '/next' => 'products#index', as: :next, next: true
        get '/special/:special_delivery_date' => 'products#index', as: :special_delivery
        resources :orders, only: %i[show update destroy] do
          post 'confirm', on: :member
          post 'unconfirm', on: :member
          resources :order_items, only: %i[create]
        end
      end
      resources :absences, only: %i[index create destroy]
      get 'billing' => 'billing#index'
      resource :member, only: %i[new show create], path: '' do
        get 'welcome', on: :collection
      end
      resource :account, only: %i[show edit update]
      resource :info, only: :show
      resource :contact_sharing, only: %i[show create]
      resource :email_suppression, only: :destroy
    end
  end
end
