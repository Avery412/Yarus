require "bigdecimal"

# Текущий остаток конкретного товара на конкретном складе.
# В отличие от StockMovement эта модель хранит актуальное состояние, а не историю.
class InventoryBalance < ApplicationRecord
  MAX_QUANTITY = BigDecimal("999999999.999")

  belongs_to :product
  belongs_to :warehouse

  validates :product_id, uniqueness: { scope: :warehouse_id }
  validates :quantity,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: MAX_QUANTITY }
  validates :minimum_quantity,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: MAX_QUANTITY }

  before_destroy :prevent_destroy_when_history_exists

  private

  # Нельзя удалять остаток, если на него уже ссылается история: иначе текущие
  # данные и журнал операций перестанут согласовываться.
  def prevent_destroy_when_history_exists
    return unless StockMovement.exists?(product_id: product_id, warehouse_id: warehouse_id)

    errors.add(:base, "Нельзя удалить остаток: по этому товару и складу уже есть история операций")
    throw(:abort)
  end
end
