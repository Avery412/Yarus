# Базовый класс ActiveRecord-моделей приложения.
# Общие настройки моделей при необходимости добавляются в одном месте.
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
end
