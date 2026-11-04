# Репозиторий складов: поиск по названию и упорядоченные списки складов.
class WarehousesRepository < ApplicationRepository
  def initialize
    super(Warehouse)
  end

  def ordered_for_select
    Warehouse.order(:name)
  end

  def list(search: nil, page: nil, per_page: nil)
    scope = Warehouse.order(:name, :id)

    if (term = search_term(search))
      pattern = "%#{Warehouse.sanitize_sql_like(term)}%"
      scope = scope.where("warehouses.name ILIKE :term", term: pattern)
    end

    paginate_relation(scope, page: page, per_page: per_page)
  end
end
