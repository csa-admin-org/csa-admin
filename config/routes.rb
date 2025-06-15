# frozen_string_literal: true

Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  resources :logos, only: :show

  constraints subdomain: "mc" do
    mount MissionControl::Jobs::Engine, at: "/jobs"
  end

  constraints subdomain: "admin" do
    resources :sessions, only: %i[show create]
    get "/login" => "sessions#new", as: :login
    delete "/logout" => "sessions#destroy", as: :logout

    resources :email_suppressions, only: :destroy

    get "activity_participations/calendar" => "activity_participations_calendar#show",
      defaults: { format: :ics }
    get "billing/:year" => "billings#show", as: :billing
    get "billing/snapshots/:id" => "billing_snapshots#show", as: :billing_snapshot

    get "settings" => "organizations#edit", as: :edit_organization
    get "settings" => "organizations#edit", as: :organizations
    resource :organization, path: "settings", only: :update

    get "deliveries/next" => "next_delivery#next"
    get "handbook/:id" => "handbook#index", as: :handbook_page

    ActiveAdmin.routes(self)

    namespace :api do
      namespace :v1 do
        resources :members, only: :create
        resource :configuration, only: :show
        get "basket_contents/current" => "basket_contents#index"
      end
    end

    namespace :postmark do
      resources :webhooks, only: :create
    end
  end

  scope module: "members", as: "members" do
    constraints subdomain: Organization::MEMBERS_SUBDOMAINS do
      resources :sessions, only: %i[show create]
      get "/login" => "sessions#new", as: :login
      delete "/logout" => "sessions#destroy", as: :logout

      get "/newsletters/unsubscribe/:token" => "newsletter_subscriptions#destroy", as: "unsubscribe_newsletter"
      #  List-Unsubscribe-Post
      post "/newsletters/unsubscribe/:token/post" => "newsletter_subscriptions#destroy", as: "unsubscribe_newsletter_post"
      post "/newsletters/subscribe/:token" => "newsletter_subscriptions#create", as: "subscribe_newsletter"

      get "/membership", to: redirect("/memberships")
      resources :memberships, only: %i[index edit update]
      resources :baskets, only: %i[edit update] do
        resource :basket_shifts, only: %i[new create], path: "shift", path_names: { new: "" }
      end

      scope :membership do
        resource :renewal,
          only: %i[new create],
          as: "membership_renewal",
          controller: "membership_renewals"
        get "renew(:format)" => "membership_renewals#new", as: "renew_membership", decision: "renew"
        get ":decision" => "membership_renewals#new"
      end

      resources :deliveries, only: :index
      resources :activities, only: :index
      resources :activity_participations, only: %i[index create destroy]
      namespace :shop do
        get "/" => "products#index"
        get "/next" => "products#index", as: :next, next: true
        get "/special/:special_delivery_date" => "products#index", as: :special_delivery
        resources :orders, only: %i[show update destroy] do
          post "confirm", on: :member
          post "unconfirm", on: :member
          resources :order_items, only: %i[create]
        end
      end
      resources :absences, only: %i[index create destroy]
      get "billing" => "billing#index"
      resource :member, only: %i[new show create], path: "" do
        get "welcome", on: :collection
      end
      resource :account, only: %i[show edit update]
      resource :info, only: :show
      resource :contact_sharing, only: %i[show create]
      resource :email_suppression, only: :destroy
      resource :calendar, only: :show, defaults: { format: :ics }
    end
  end
end
