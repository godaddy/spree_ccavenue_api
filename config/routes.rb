Spree::Core::Engine.routes.draw do
  match '/ccavenue/:id/show/:order_id'                     => 'ccavenue#show',     :as => :ccavenue_order_confirmation, via: :get
  match '/ccavenue/:id/callback/:order_id/:transaction_id' => 'ccavenue#callback', :as => :ccavenue_callback, via: :post

  namespace :admin do
    resources :payment_methods do
      member do
        get :ccavenue_verify
      end
    end
  end
end
