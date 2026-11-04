# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_03_000500) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "inventory_balances", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "warehouse_id", null: false
    t.decimal "quantity", precision: 12, scale: 3, default: "0.0", null: false
    t.decimal "minimum_quantity", precision: 12, scale: 3, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "warehouse_id"], name: "index_inventory_balances_on_product_and_warehouse", unique: true
    t.index ["product_id"], name: "index_inventory_balances_on_product_id"
    t.index ["warehouse_id"], name: "index_inventory_balances_on_warehouse_id"
    t.check_constraint "minimum_quantity >= 0::numeric", name: "inventory_balances_minimum_quantity_non_negative"
    t.check_constraint "quantity >= 0::numeric", name: "inventory_balances_quantity_non_negative"
  end

  create_table "products", force: :cascade do |t|
    t.string "name", null: false
    t.string "sku", null: false
    t.text "description"
    t.string "unit", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sku"], name: "index_products_on_sku", unique: true
  end

  create_table "stock_movements", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "warehouse_id", null: false
    t.bigint "user_id", null: false
    t.string "movement_type", null: false
    t.decimal "quantity", precision: 12, scale: 3, null: false
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at", "id"], name: "index_stock_movements_on_created_at_and_id"
    t.index ["product_id", "warehouse_id"], name: "index_stock_movements_on_product_id_and_warehouse_id"
    t.index ["product_id"], name: "index_stock_movements_on_product_id"
    t.index ["user_id"], name: "index_stock_movements_on_user_id"
    t.index ["warehouse_id"], name: "index_stock_movements_on_warehouse_id"
    t.check_constraint "movement_type::text = ANY (ARRAY['receipt'::character varying, 'issue'::character varying]::text[])", name: "stock_movements_type_must_be_supported"
    t.check_constraint "quantity > 0::numeric", name: "stock_movements_quantity_positive"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "role", default: "warehouse_operator", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.check_constraint "role::text = ANY (ARRAY['manager'::character varying, 'warehouse_operator'::character varying]::text[])", name: "users_role_must_be_supported"
  end

  create_table "warehouses", force: :cascade do |t|
    t.string "name", null: false
    t.string "address"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "inventory_balances", "products"
  add_foreign_key "inventory_balances", "warehouses"
  add_foreign_key "stock_movements", "products"
  add_foreign_key "stock_movements", "users"
  add_foreign_key "stock_movements", "warehouses"
end
