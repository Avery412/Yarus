# Создаёт каталог товаров. Уникальный индекс SKU защищает от дублей
# даже при одновременных запросах из разных процессов приложения.
class CreateProducts < ActiveRecord::Migration[7.1]
  def change
    create_table :products do |t|
      t.string :name, null: false
      t.string :sku, null: false
      t.text :description
      t.string :unit, null: false

      t.timestamps
    end

    add_index :products, :sku, unique: true
  end
end
