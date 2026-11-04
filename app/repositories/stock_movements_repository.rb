# Репозиторий истории складских операций. Он отвечает за фильтры и порядок
# истории, но не изменяет остатки: это задача StockMovements::Create.
class StockMovementsRepository < ApplicationRepository
  VALID_MOVEMENT_TYPES = %w[receipt issue].freeze

  def initialize
    super(StockMovement)
  end

  def list(filters: {}, page: nil, per_page: nil)
    scope = StockMovement.includes(:product, :warehouse, :user)
                         .joins(:product, :warehouse)
                         .order(created_at: :desc, id: :desc)

    if (id = safe_id(filters[:product_id]))
      scope = scope.where(product_id: id)
    end

    if (id = safe_id(filters[:warehouse_id]))
      scope = scope.where(warehouse_id: id)
    end

    movement_type = filters[:movement_type].to_s
    if VALID_MOVEMENT_TYPES.include?(movement_type)
      scope = scope.where(movement_type: movement_type)
    end

    if (term = search_term(filters[:search]))
      pattern = "%#{Product.sanitize_sql_like(term)}%"
      scope = scope.where(
        "products.name ILIKE :term OR products.sku ILIKE :term OR warehouses.name ILIKE :term",
        term: pattern
      )
    end

    if (start_date = parse_date(filters[:start_date]))
      scope = scope.where("stock_movements.created_at >= ?", start_date.beginning_of_day)
    end

    if (end_date = parse_date(filters[:end_date]))
      scope = scope.where("stock_movements.created_at <= ?", end_date.end_of_day)
    end

    paginate_relation(scope, page: page, per_page: per_page)
  end

  private

  # Ошибочный формат даты не должен приводить к 500. Такой фильтр пропускается,
  # а остальные корректные условия продолжают применяться.
  def parse_date(value)
    return if value.blank?

    Date.iso8601(value.to_s)
  rescue Date::Error, ArgumentError
    nil
  end
end
