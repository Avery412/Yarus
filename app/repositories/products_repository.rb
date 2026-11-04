# Репозиторий товаров: единая точка для выборок, поиска и пагинации товаров.
class ProductsRepository < ApplicationRepository
  def initialize
    super(Product)
  end

  def ordered_for_select
    Product.order(:name)
  end

  def list(search: nil, page: nil, per_page: nil)
    scope = Product.order(:name, :id)

    if (term = search_term(search))
      pattern = "%#{Product.sanitize_sql_like(term)}%"
      scope = scope.where("products.name ILIKE :term OR products.sku ILIKE :term", term: pattern)
    end

    paginate_relation(scope, page: page, per_page: per_page)
  end
end
