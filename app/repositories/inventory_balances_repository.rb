# Запросы к текущим остаткам и безопасное получение строки остатка
# для изменения внутри складской транзакции.
class InventoryBalancesRepository < ApplicationRepository
  def initialize
    super(InventoryBalance)
  end

  def list(search: nil, product_id: nil, warehouse_id: nil, page: nil, per_page: nil)
    scope = InventoryBalance.includes(:product, :warehouse).joins(:product, :warehouse)
                            .order("products.name ASC", "warehouses.name ASC", "inventory_balances.id ASC")

    if (id = safe_id(product_id))
      scope = scope.where(product_id: id)
    end

    if (id = safe_id(warehouse_id))
      scope = scope.where(warehouse_id: id)
    end

    if (term = search_term(search))
      pattern = "%#{Product.sanitize_sql_like(term)}%"
      scope = scope.where(
        "products.name ILIKE :term OR products.sku ILIKE :term OR warehouses.name ILIKE :term",
        term: pattern
      )
    end

    paginate_relation(scope, page: page, per_page: per_page)
  end

  # Обновление остатка разрешено только внутри транзакции складской операции.
  def update_quantity!(balance, quantity:)
    ensure_transaction!
    balance.update!(quantity: quantity)
    balance
  end

  # Метод вызывается внутри транзакции. Сначала INSERT ... ON CONFLICT DO NOTHING
  # пытается создать нулевой остаток. Уникальный индекс по паре product_id и
  # warehouse_id не позволяет создать две строки при одновременных первых
  # операциях. Затем SELECT FOR UPDATE блокирует найденную строку до конца
  # транзакции, чтобы параллельный приход/расход дождался завершения текущего.
  def find_or_create_locked!(product:, warehouse:)
    ensure_transaction!

    keys = { product_id: product.id, warehouse_id: warehouse.id }

    InventoryBalance.insert_all(
      [keys.merge(quantity: 0, minimum_quantity: 0)],
      unique_by: :index_inventory_balances_on_product_and_warehouse
    )

    InventoryBalance.lock.find_by!(keys)
  end

  private

  def ensure_transaction!
    return if InventoryBalance.current_transaction.open?

    raise ArgumentError, "Изменение остатка должно выполняться внутри транзакции"
  end
end
