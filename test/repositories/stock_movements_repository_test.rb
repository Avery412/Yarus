require "test_helper"

class StockMovementsRepositoryTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "history@example.test")
    @product = Product.create!(name: "Исторический товар", sku: "HISTORY-001", unit: "шт.")
    @warehouse = Warehouse.create!(name: "Исторический склад")
    @service = ->(type, quantity) do
      StockMovements::Create.new(
        product: @product,
        warehouse: @warehouse,
        user: @user,
        movement_type: type,
        quantity: quantity
      ).call
    end
    @service.call("receipt", "10")
    @service.call("issue", "2")
    @repository = StockMovementsRepository.new
  end

  test "list filters by supported movement type" do
    page = @repository.list(filters: { movement_type: "receipt" })

    assert_equal 1, page.total_count
    assert_equal ["receipt"], page.records.map(&:movement_type)
  end

  test "list ignores unsupported movement type and malformed date" do
    page = @repository.list(
      filters: { movement_type: "transfer", start_date: "not-a-date" }
    )

    assert_equal 2, page.total_count
  end

  test "list filters by product and paginates results" do
    page = @repository.list(
      filters: { product_id: @product.id.to_s },
      page: "1",
      per_page: "1"
    )

    assert_equal 2, page.total_count
    assert_equal 1, page.records.length
    assert_equal 2, page.total_pages
  end
end
