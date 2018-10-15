Rails.application.routes.draw do
  resources :favicons, only: [:index]
end
