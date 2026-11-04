# Создаёт неизменяемую историю прихода и расхода. Внешние ключи сохраняют
# связь с товаром, складом и автором операции; CHECK-constraints проверяют
# допустимый тип движения и положительное количество на уровне PostgreSQL.
class CreateStockMovements < ActiveRecord::Migration[7.1]
  def change
    create_table :stock_movements do |t|
      t.references :product, null: false, foreign_key: true
      t.references :warehouse, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :movement_type, null: false
      t.decimal :quantity, precision: 12, scale: 3, null: false
      t.text :note

      t.timestamps
    end

    add_index :stock_movements, %i[created_at id]
    add_index :stock_movements, %i[product_id warehouse_id]
    add_check_constraint :stock_movements,
                         "movement_type IN ('receipt', 'issue')",
                         name: "stock_movements_type_must_be_supported"
    add_check_constraint :stock_movements, "quantity > 0",
                         name: "stock_movements_quantity_positive"
  end
end
