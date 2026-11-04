# Маршруты складского функционала остаются частью обычного Rails MVC-приложения.
# Главная страница starter-проекта сохранена как root route.
Rails.application.routes.draw do
  root "home#index"
  get "home/index"

  resources :products, only: %i[index show new create edit update]
  resources :warehouses, only: %i[index show new create edit update]
  resources :inventory_balances, only: %i[index show]
  resources :stock_movements, only: %i[index show new create]

  # Reveal health status on /up.
  get "up" => "rails/health#show", as: :rails_health_check
end
