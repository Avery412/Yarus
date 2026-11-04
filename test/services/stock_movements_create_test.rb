require "test_helper"

class StockMovementsCreateTest < ActiveSupport::TestCase
  class FailingStockMovementsRepository
    def create!(**_attributes)
      raise ActiveRecord::RecordInvalid.new(StockMovement.new)
    end
  end

  setup do
    @user = User.create!(email: "operator@example.test")
    @product = Product.create!(name: "Тестовый товар", sku: "TEST-001", unit: "шт.")
    @warehouse = Warehouse.create!(name: "Тестовый склад")
  end

  test "receipt creates balance and one history entry" do
    movement = perform_movement(type: "receipt", quantity: "10")

    balance = InventoryBalance.find_by!(product: @product, warehouse: @warehouse)
    assert_equal BigDecimal("10.000"), balance.quantity
    assert_equal 1, StockMovement.count
    assert_equal "receipt", movement.movement_type
    assert_equal BigDecimal("10.000"), movement.quantity
  end

  test "issue subtracts quantity and appends history" do
    perform_movement(type: "receipt", quantity: "10")

    movement = perform_movement(type: "issue", quantity: "3.25")

    balance = InventoryBalance.find_by!(product: @product, warehouse: @warehouse)
    assert_equal BigDecimal("6.750"), balance.quantity
    assert_equal 2, StockMovement.count
    assert_equal "issue", movement.movement_type
  end

  test "insufficient stock rolls back and does not create history" do
    perform_movement(type: "receipt", quantity: "6.75")

    assert_no_difference("StockMovement.count") do
      error = assert_raises(StockMovements::Create::InsufficientStockError) do
        perform_movement(type: "issue", quantity: "7")
      end
      assert_match "Недостаточно товара", error.message
    end

    balance = InventoryBalance.find_by!(product: @product, warehouse: @warehouse)
    assert_equal BigDecimal("6.750"), balance.quantity
  end

  test "invalid quantities are rejected before database changes" do
    ["0", "-1", "1.0001", "1000000000", "NaN", "Infinity", "not-a-number"].each do |value|
      assert_no_difference("StockMovement.count") do
        assert_raises(StockMovements::Create::InvalidQuantityError) do
          build_service(type: "receipt", quantity: value).call
        end
      end
    end
  end

  test "unsupported movement type is rejected" do
    assert_raises(StockMovements::Create::InvalidMovementTypeError) do
      perform_movement(type: "transfer", quantity: "1")
    end

    assert_equal 0, StockMovement.count
    assert_equal 0, InventoryBalance.count
  end

  test "transaction rolls back balance update when history insert fails" do
    perform_movement(type: "receipt", quantity: "10")
    service = build_service(
      type: "issue",
      quantity: "3",
      stock_movements_repository: FailingStockMovementsRepository.new
    )

    assert_raises(ActiveRecord::RecordInvalid) { service.call }

    balance = InventoryBalance.find_by!(product: @product, warehouse: @warehouse)
    assert_equal BigDecimal("10.000"), balance.quantity
    assert_equal 1, StockMovement.count
  end

  test "receipt cannot make the stored decimal balance overflow" do
    perform_movement(type: "receipt", quantity: "999999999.999")

    assert_no_difference("StockMovement.count") do
      assert_raises(StockMovements::Create::BalanceLimitExceededError) do
        perform_movement(type: "receipt", quantity: "0.001")
      end
    end

    balance = InventoryBalance.find_by!(product: @product, warehouse: @warehouse)
    assert_equal BigDecimal("999999999.999"), balance.quantity
  end

  test "stock movement cannot be updated or destroyed through normal ActiveRecord methods" do
    movement = perform_movement(type: "receipt", quantity: "2")

    assert_not movement.update(quantity: BigDecimal("3"))
    assert_not movement.destroy
    assert_equal BigDecimal("2.000"), movement.reload.quantity
    assert_equal 1, StockMovement.count
  end

  test "service requires a persisted user" do
    service = StockMovements::Create.new(
      product: @product,
      warehouse: @warehouse,
      user: nil,
      movement_type: "receipt",
      quantity: "1"
    )

    assert_raises(StockMovements::Create::InvalidReferenceError) { service.call }
  end

  private

  def perform_movement(type:, quantity:)
    build_service(type: type, quantity: quantity).call
  end

  def build_service(type:, quantity:, stock_movements_repository: StockMovementsRepository.new)
    StockMovements::Create.new(
      product: @product,
      warehouse: @warehouse,
      user: @user,
      movement_type: type,
      quantity: quantity,
      stock_movements_repository: stock_movements_repository
    )
  end
end
