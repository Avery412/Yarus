ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Небольшой backend-набор запускается последовательно: так тесты с PostgreSQL
    # остаются предсказуемыми на локальной Windows-машине и не создают лишние БД.
    fixtures :all
  end
end
