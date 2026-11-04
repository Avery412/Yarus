require "bigdecimal"

# Неизменяемая запись факта прихода или расхода товара.
# Текущий остаток меняется сервисом, а записи истории используются для аудита.
class StockMovement < ApplicationRecord
  MAX_QUANTITY = BigDecimal("999999999.999")

  enum :movement_type, {
    receipt: "receipt",
    issue: "issue"
  }

  belongs_to :product
  belongs_to :warehouse
  belongs_to :user

  validates :movement_type, presence: true, inclusion: { in: movement_types.keys }
  validates :quantity,
            numericality: { greater_than: 0, less_than_or_equal_to: MAX_QUANTITY }
  validates :note, length: { maximum: 5_000 }, allow_nil: true

  before_update :prevent_history_modification
  before_destroy :prevent_history_modification

  private

  # Исправление ошибочной операции оформляется новой обратной операцией,
  # а не редактированием старой записи — так сохраняется достоверная история.
  def prevent_history_modification
    errors.add(:base, "История складских операций неизменяема. Создайте обратную операцию.")
    throw(:abort)
  end
end
