# Пользователь, от имени которого фиксируются складские операции.
# Роль хранится строкой и ограничена допустимыми значениями также на уровне БД.
class User < ApplicationRecord
  enum :role, {
    warehouse_operator: "warehouse_operator",
    manager: "manager"
  }, default: :warehouse_operator

  has_many :stock_movements, dependent: :restrict_with_error

  before_validation :normalize_email

  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :role, presence: true

  private

  # Единый формат email снижает риск появления дублей из-за регистра
  # и случайных пробелов по краям адреса.
  def normalize_email
    self.email = email.to_s.strip.downcase if email.present?
  end
end
