require 'sidekiq/web'
require 'sidekiq/cron/web'

Rails.application.routes.draw do
  concern :access_requestable do
    post :request_access, on: :collection
    post :approve_access_request, on: :member
  end

  concern :awardable do
    post :toggle_award_emoji, on: :member
  end

  favicon_redirect = redirect do |_params, _request|
    ActionController::Base.helpers.asset_url(Gitlab::Favicon.main)
  end
  get 'favicon.png', to: favicon_redirect
  get 'favicon.ico', to: favicon_redirect

  draw :sherlock
  draw :development
  draw :ci

  use_doorkeeper do
    controllers applications: 'oauth/applications',
                authorized_applications: 'oauth/authorized_applications',
                authorizations: 'oauth/authorizations'
  end

  # This is here so we can "reserve" the path for the Jira integration in GitLab EE
  # Having a non-existent controller here does not affect the scope in any way since all possible routes
  # get a 404 proc returned. It is written in this way to minimize merge conflicts with EE
  scope path: '/login/oauth', controller: 'oauth/jira/authorizations', as: :oauth_jira do
    match '*all', via: [:get, :post], to: proc { [404, {}, ['']] }
  end

  draw :oauth

  use_doorkeeper_openid_connect

  # Autocomplete
  get '/autocomplete/users' => 'autocomplete#users'
  get '/autocomplete/users/:id' => 'autocomplete#user'
  get '/autocomplete/projects' => 'autocomplete#projects'
  get '/autocomplete/award_emojis' => 'autocomplete#award_emojis'
  get '/autocomplete/merge_request_target_branches' => 'autocomplete#merge_request_target_branches'

  # Search
  get 'search' => 'search#show'
  get 'search/autocomplete' => 'search#autocomplete', as: :search_autocomplete

  # JSON Web Token
  get 'jwt/auth' => 'jwt#auth'

  # Health check
  get 'health_check(/:checks)' => 'health_check#index', as: :health_check

  scope path: '-' do
    # '/-/health' implemented by BasicHealthMiddleware
    get 'liveness' => 'health#liveness'
    get 'readiness' => 'health#readiness'
    resources :metrics, only: [:index]
    mount Peek::Railtie => '/peek', as: 'peek_routes'

    # Boards resources shared between group and projects
    resources :boards, only: [] do
      resources :lists, module: :boards, only: [:index, :create, :update, :destroy] do
        collection do
          post :generate
        end

        resources :issues, only: [:index, :create, :update]
      end

      resources :issues, module: :boards, only: [:index, :update]
    end

    get 'acme-challenge/' => 'acme_challenges#show'

    # UserCallouts
    resources :user_callouts, only: [:create]

    get 'ide' => 'ide#index'
    get 'ide/*vueroute' => 'ide#index', format: false

    draw :operations
    draw :instance_statistics

    if ENV['GITLAB_ENABLE_CHAOS_ENDPOINTS']
      get '/chaos/leakmem' => 'chaos#leakmem'
      get '/chaos/cpuspin' => 'chaos#cpuspin'
      get '/chaos/sleep' => 'chaos#sleep'
      get '/chaos/kill' => 'chaos#kill'
    end
  end

  concern :clusterable do
    resources :clusters, only: [:index, :new, :show, :update, :destroy] do
      collection do
        post :create_user
        post :create_gcp
      end

      member do
        scope :applications do
          post '/:application', to: 'clusters/applications#create', as: :install_applications
          patch '/:application', to: 'clusters/applications#update', as: :update_applications
          delete '/:application', to: 'clusters/applications#destroy', as: :uninstall_applications
        end

        get :cluster_status, format: :json
      end
    end
  end

  draw :api
  draw :sidekiq
  draw :help
  draw :snippets

  # Invites
  resources :invites, only: [:show], constraints: { id: /[A-Za-z0-9_-]+/ } do
    member do
      post :accept
      match :decline, via: [:get, :post]
    end
  end

  resources :sent_notifications, only: [], constraints: { id: /\h{32}/ } do
    member do
      get :unsubscribe
    end
  end

  # Spam reports
  resources :abuse_reports, only: [:new, :create]

  # Notification settings
  resources :notification_settings, only: [:create, :update]

  draw :google_api
  draw :import
  draw :uploads
  draw :explore
  draw :admin
  draw :profile
  draw :dashboard
  draw :group
  draw :user
  draw :project

  root to: "root#index"

  get '*unmatched_route', to: 'application#route_not_found'
end
