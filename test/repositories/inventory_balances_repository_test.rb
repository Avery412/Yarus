require "test_helper"

class InventoryBalancesRepositoryTest < ActiveSupport::TestCase
  setup do
    @product = Product.create!(name: "Репозиторный товар", sku: "REPO-001", unit: "шт.")
    @warehouse = Warehouse.create!(name: "Репозиторный склад")
    @repository = InventoryBalancesRepository.new
  end

  test "find_or_create_locked! creates one zero balance inside a transaction" do
    first_balance, second_balance = InventoryBalance.transaction do
      first = @repository.find_or_create_locked!(product: @product, warehouse: @warehouse)
      second = @repository.find_or_create_locked!(product: @product, warehouse: @warehouse)
      [first, second]
    end

    assert_equal first_balance.id, second_balance.id
    assert_equal BigDecimal("0.000"), first_balance.quantity
    assert_equal 1, InventoryBalance.count
  end

  test "find_or_create_locked! refuses to run outside a transaction" do
    assert_raises(ArgumentError) do
      @repository.find_or_create_locked!(product: @product, warehouse: @warehouse)
    end

    assert_equal 0, InventoryBalance.count
  end

  test "list ignores malformed identifiers and applies pagination" do
    second_product = Product.create!(name: "Репозиторный товар 2", sku: "REPO-002", unit: "шт.")
    InventoryBalance.create!(product: @product, warehouse: @warehouse, quantity: 1)
    InventoryBalance.create!(product: second_product, warehouse: @warehouse, quantity: 2)

    result = @repository.list(product_id: "bad-id", page: "1", per_page: "1")

    assert_equal 2, result.total_count
    assert_equal 1, result.records.length
    assert_equal 2, result.total_pages
  end
end
