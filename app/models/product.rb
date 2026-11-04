# Товар, который учитывается на одном или нескольких складах.
class Product < ApplicationRecord
  has_many :inventory_balances, dependent: :restrict_with_error
  has_many :warehouses, through: :inventory_balances
  has_many :stock_movements, dependent: :restrict_with_error

  validates :name, presence: true, length: { maximum: 150 }
  validates :sku, presence: true, uniqueness: true, length: { maximum: 100 }
  validates :unit, presence: true, length: { maximum: 30 }
  validates :description, length: { maximum: 5_000 }, allow_nil: true
end
