# Создаёт учётные записи пользователей и сохраняет набор полей,
# совместимый с распространёнными механизмами аутентификации.
# Роль дополнительно ограничена CHECK-constraint на уровне PostgreSQL.
class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :encrypted_password, null: false, default: ""
      t.string :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at
      t.string :role, null: false, default: "warehouse_operator"

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :reset_password_token, unique: true

    add_check_constraint :users,
                         "role IN ('manager', 'warehouse_operator')",
                         name: "users_role_must_be_supported"
  end
end
