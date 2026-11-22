require "test_helper"
require "json"

class ReactWorkspaceTest < ActionDispatch::IntegrationTest
  setup do
    @password = "warehouse-test-password"
    @user = User.create!(email: "operator@example.test", password: @password)
    @product = Product.create!(name: "Плитка", sku: "TL-01", unit: "м²")
    @warehouse = Warehouse.create!(name: "Северный", address: "Складская, 1")
  end

  test "session protects workspace and returns the user to the original page" do
    get products_path(search: "Плитка")
    assert_redirected_to new_session_path

    post session_path, params: { email: @user.email, password: "incorrect" }
    assert_response :unprocessable_entity
    assert_equal "sign_in", payload.fetch("screen")

    sign_in
    assert_redirected_to products_path(search: "Плитка")
    follow_redirect!
    assert_equal [@product.id], props.fetch("rows").pluck("id")
    assert_equal @user.email, payload.fetch("user").fetch("email")
    assert_not_includes response.body, @user.encrypted_password

    delete session_path
    assert_redirected_to root_path
    get products_path
    assert_redirected_to new_session_path
  end

  test "catalog routes render real records, forms and duplicate SKU errors" do
    sign_in
    [
      [products_path, "products"], [product_path(@product), "product"],
      [new_product_path, "product_form"], [edit_product_path(@product), "product_form"],
      [warehouses_path, "warehouses"], [warehouse_path(@warehouse), "warehouse"],
      [new_warehouse_path, "warehouse_form"], [edit_warehouse_path(@warehouse), "warehouse_form"],
      [inventory_balances_path, "inventory_balances"], [stock_movements_path, "stock_movements"],
      [new_stock_movement_path, "movement_form"]
    ].each do |path, screen|
      get path
      assert_response :success
      assert_equal screen, payload.fetch("screen")
    end

    assert_no_difference "Product.count" do
      post products_path, params: { product: { name: "Дубликат", sku: @product.sku, unit: "шт." } }
    end
    assert_response :unprocessable_entity
    assert props.fetch("errors").key?("sku")
    assert_equal "Дубликат", props.fetch("values").fetch("name")

    assert_difference "Product.count", 1 do
      post products_path, params: { product: { name: "Кирпич", sku: "BR-01", unit: "шт." } }
    end
    assert_redirected_to product_path(Product.find_by!(sku: "BR-01"))
    patch product_path(@product), params: { product: { name: "Плитка для пола" } }
    assert_redirected_to product_path(@product)
    assert_equal "Плитка для пола", @product.reload.name

    assert_difference "Warehouse.count", 1 do
      post warehouses_path, params: { warehouse: { name: "Южный", address: "Складская, 2" } }
    end
    assert_redirected_to warehouse_path(Warehouse.find_by!(name: "Южный"))
    patch warehouse_path(@warehouse), params: { warehouse: { address: "Новый адрес" } }
    assert_redirected_to warehouse_path(@warehouse)
    assert_equal "Новый адрес", @warehouse.reload.address
  end

  test "operations are authored by the session and show precise results and preserved errors" do
    sign_in
    record_movement("receipt", "10")
    assert_redirected_to stock_movement_path(StockMovement.last)
    assert_equal @user, StockMovement.last.user
    assert_equal BigDecimal("10"), InventoryBalance.last.quantity

    record_movement("issue", "3,25")
    assert_redirected_to stock_movement_path(StockMovement.last)
    assert_equal BigDecimal("6.75"), InventoryBalance.last.quantity
    follow_redirect!
    assert_equal @user.email, props.fetch("record").fetch("author")

    assert_no_difference "StockMovement.count" do
      record_movement("issue", "7")
    end
    assert_response :unprocessable_entity
    assert_match "Недостаточно товара", props.fetch("errors").fetch("base").first
    assert_equal "7", props.fetch("values").fetch("quantity")
    assert_equal BigDecimal("6.75"), InventoryBalance.last.quantity

    %w[0 -1 1.0001 1000000000 NaN abc].each do |invalid|
      assert_no_difference "StockMovement.count" do
        record_movement("receipt", invalid)
      end
      assert_response :unprocessable_entity
      assert_equal invalid, props.fetch("values").fetch("quantity")
    end

    record_movement("receipt", "1", product_id: 0)
    assert_response :unprocessable_entity
    assert_equal "0", props.fetch("values").fetch("product_id")
    assert_equal BigDecimal("6.75"), InventoryBalance.last.quantity

    get inventory_balance_path(InventoryBalance.last)
    assert_equal "inventory_balance", payload.fetch("screen")
    get stock_movements_path(movement_type: "receipt", product_id: @product.id)
    assert_equal ["receipt"], props.fetch("rows").pluck("movement_type")
    get stock_movements_path(movement_type: "bogus", start_date: "broken", per_page: 999)
    assert_response :success
    assert_equal 100, props.fetch("pagination").fetch("per_page")
    assert_equal 2, props.fetch("rows").length
  end

  private

  def sign_in
    post session_path, params: { email: " OPERATOR@example.test ", password: @password }
  end

  def record_movement(type, quantity, product_id: @product.id)
    post stock_movements_path, params: { stock_movement: {
      product_id: product_id, warehouse_id: @warehouse.id, movement_type: type,
      quantity: quantity, note: "Примечание", user_id: @user.id + 999
    } }
  end

  def payload
    JSON.parse(Nokogiri::HTML(response.body).at_css("#yarus-data").text)
  end

  def props
    payload.fetch("props")
  end
end
