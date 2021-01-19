Gluedb::Application.routes.draw do

  devise_for :users, :path => "accounts"

  root :to => 'dashboards#index'

  get "dashboards/index"
  get "welcome/index"
  get "tools/premium_calc"
  get "flatuipro_demo/index"

  post "policy_forms", :to => 'policies#create'

  resources :users

  resources :legacy_cv_transactions, only: %i[show index]

  resources :enrollment_action_issues, only: [:index, :show] do
  end

  # concern :commentable do
  #   resources :comments #, only: [:new, :create]
  # end
  resources :employer_events, only: [:index] do
    collection do
      post :publish
      get :download
    end
  end

  namespace :admin do
    namespace :settings do
      resources :hbx_policies
    end
    resources :users
  end

  resources :families do
    get 'page/:page', :action => :index, :on => :collection

    # resources :primary_applicant, only: [:new, :create, :update]
    resources :family_members

    member do
      get :link_employee
      get :challenge_identity
    end

    resources :households
  end

  resources :coverage_households

  resources :tax_households do
    resources :eligibility_determinations
    resources :tax_household_members
  end

  resources :hbx_enrollments
  resources :irs_groups

  resources :enrollment_addresses

  resources :plan_metrics, :only => :index

  resources :vocab_uploads, :only => [:new, :create]
  resources :member_address_changes, :only => [:new, :create]
  resources :effective_date_changes, :only => [:new, :create]
  resources :mass_silent_cancels, :only => [:new, :create]
  resources :bulk_terminates, :only => [:new, :create]

  resources :enrollment_transmission_updates, :only => :create

  resources(:change_vocabularies, :only => [:new, :create]) do
    collection do
      get 'download'
    end
  end

  resources :edi_ops_transactions do
    resources :comments
  end
  resources(:vocabulary_requests, :only => [:new, :create])

  resources :edi_transaction_set_payments
  resources :edi_transaction_sets do
    collection do
      get :errors
    end
  end
  resources :edi_transmissions

  resources :csv_transactions, :only => :show

  resources :enrollments do
    member do
      get :canonical_vocabulary
    end
  end

  resources :policies, only: [:new, :show, :create, :edit, :update, :index] do
    member do
      get :cancelterminate
      post :transmit
      get :generate_tax_document_form
      post :generate_tax_document
      get :download_tax_document
      post :upload_tax_document_to_S3
      delete :delete_local_generated_tax_document
    end
  end

  resources :individuals
  resources :people do
    resources :comments
    get 'page/:page', :action => :index, :on => :collection
    member do
      put :compare
      put :persist_and_transmit
      put :assign_authority_id
    end
  end

  resources :employers do
    get 'page/:page', action: :index, :on => :collection
    member do
      get :group
    end
    resources :employees, except: [:destroy], on: :member do
      member do
        put :compare
        put :terminate
      end
    end
  end

  resources :brokers do
    get 'page/:page', :action => :index, :on => :collection
  end

  resources :carriers do
    resources :plans
    get :show_plans
    get :plan_years
    post :calculate_premium, on: :collection
  end

  resources :plans, only: [:index, :show] do
    member do
      get :calculate_premium
    end
  end

  namespace :resources do
    namespace :v1 do
      resources :individuals, :only => [:show]
      resources :policies, :only => [:show]
      resources :families, :only => [:show]
    end 
  end

  namespace :api, :defaults => { :format => 'xml' } do
    namespace :v1 do
      resources :events, :only => [:create]
      resources :people, :only => [:show, :index]
      resources :employers, :only => [:show, :index] do
        member do
          get :old_cv
        end
        collection do
          get :old_group_index
        end
      end
      resources :policies, :only => [:show, :index]
      resources :families, :only => [:show, :index]
      resources :households, :only => [:show, :index]
      resources :irs_reports, :only => [:index]
      resources :application_groups, :controller => :families, :only => [:show, :index]

    end
    namespace :v2 do
      resources :events, :only => [:create]
      resources :people, :only => [:show, :index]
      resources :employers, :only => [:show, :index]
      resources :policies, :only => [:show, :index]
      resources :families, :only => [:show, :index]
      resources :households, :only => [:show, :index]
      resources :irs_reports, :only => [:index]
      resources :plans, :only => [:show]
      resources :renewal_policies, :only => [:show, :index]
      #resources :premium_calculator
      post 'calculate_premium', to: 'premium_calculator#calculate'
      resources :application_groups, :controller => :families, :only => [:show, :index]
      post 'generate_quote', to: 'quote_generator#generate'
    end
  end

  resources :special_enrollment_periods, only: [:new, :create]

  resources :carefirst_imports do
    collection do
      post 'update_policy_status'
      post 'update_enrollee_status'
    end
  end

  resources :carefirst_policy_updates, only: [:create] do
    collection do
      post 'upload_csv'
    end
  end

  namespace :soap do
    resources :individuals, :only => [] do
      collection do
        post 'get_by_hbx_id'
        get 'wsdl'
      end
    end
    resources :policies, :only => [] do
      collection do
        post 'get_by_policy_id'
        get 'wsdl'
      end
    end
    resources :families, :only => [] do
      collection do
        post 'get_by_family_id'
        get 'wsdl'
      end
    end
    resources :employers, :only => [] do
      collection do
        post 'get_by_employer_id'
        get 'wsdl'
      end
    end

    #duplicate route with old resource name
    resources :application_groups, :controller => :families,:only => [] do
      collection do
        post 'get_by_family_id'
        get 'wsdl'
      end
    end
  end


  # The priority is based upon order of creation:
  # first created -> highest priority.

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id))(.:format)'

end
