# Склад, на котором хранится учётное количество товаров.
class Warehouse < ApplicationRecord
  has_many :inventory_balances, dependent: :restrict_with_error
  has_many :products, through: :inventory_balances
  has_many :stock_movements, dependent: :restrict_with_error

  validates :name, presence: true, length: { maximum: 150 }
  validates :address, length: { maximum: 255 }, allow_nil: true
  validates :description, length: { maximum: 5_000 }, allow_nil: true
end
