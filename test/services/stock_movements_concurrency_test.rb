require "test_helper"
require "timeout"

class StockMovementsConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  test "two first receipts use independent connections and produce one balance" do
    suffix = SecureRandom.hex(6)
    product = Product.create!(name: "Concurrent receipt", sku: "parallel-#{suffix}", unit: "шт.")
    warehouse = Warehouse.create!(name: "Parallel warehouse #{suffix}")
    user = User.create!(email: "parallel-#{suffix}@example.test")
    ids = { product_id: product.id, warehouse_id: warehouse.id }
    ready = Queue.new
    start = Queue.new

    workers = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do |connection|
          ready << connection.raw_connection.backend_pid
          start.pop
          StockMovements::Create.new(product: product, warehouse: warehouse, user: user,
                                     movement_type: "receipt", quantity: "5").call
        end
      end
    end

    Timeout.timeout(15) do
      connection_ids = 2.times.map { ready.pop }
      2.times { start << true }
      workers.each(&:value)
      assert_equal 2, connection_ids.uniq.size
    end

    assert_equal 1, InventoryBalance.where(ids).count
    assert_equal BigDecimal("10"), InventoryBalance.find_by!(ids).quantity
    assert_equal 2, StockMovement.where(ids).count
  ensure
    workers&.each do |worker|
      worker.kill if worker.alive?
      worker.join
    rescue StandardError
      # The worker's original exception is raised by Thread#value above.
    end
    if ids
      StockMovement.where(ids).delete_all
      InventoryBalance.where(ids).delete_all
    end
    product&.destroy!
    warehouse&.destroy!
    user&.destroy!
  end
end
