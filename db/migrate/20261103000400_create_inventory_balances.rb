# Создаёт таблицу текущих остатков. Уникальная пара товара и склада
# гарантирует одну строку баланса, а CHECK-constraints запрещают отрицательные
# значения независимо от того, каким способом приложение обращается к БД.
class CreateInventoryBalances < ActiveRecord::Migration[7.1]
  def change
    create_table :inventory_balances do |t|
      t.references :product, null: false, foreign_key: true
      t.references :warehouse, null: false, foreign_key: true
      t.decimal :quantity, precision: 12, scale: 3, null: false, default: 0
      t.decimal :minimum_quantity, precision: 12, scale: 3, null: false, default: 0

      t.timestamps
    end

    add_index :inventory_balances, %i[product_id warehouse_id],
              unique: true,
              name: "index_inventory_balances_on_product_and_warehouse"

    add_check_constraint :inventory_balances, "quantity >= 0",
                         name: "inventory_balances_quantity_non_negative"
    add_check_constraint :inventory_balances, "minimum_quantity >= 0",
                         name: "inventory_balances_minimum_quantity_non_negative"
  end
end
