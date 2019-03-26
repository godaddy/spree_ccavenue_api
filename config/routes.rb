# frozen_string_literal: true

Spree::Core::Engine.routes.draw do
  get '/ccavenue/:id/show' => 'ccavenue#show', as: :ccavenue_order_confirmation
  post '/ccavenue/:id/callback' => 'ccavenue#callback', as: :ccavenue_callback

  namespace :admin do
    resources :payment_methods do
      member do
        get :ccavenue_verify
      end
    end
  end
end
