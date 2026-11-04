# Создаёт справочник складов, на которых ведётся учёт остатков.
class CreateWarehouses < ActiveRecord::Migration[7.1]
  def change
    create_table :warehouses do |t|
      t.string :name, null: false
      t.string :address
      t.text :description

      t.timestamps
    end
  end
end
