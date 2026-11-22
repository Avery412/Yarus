module ReactWorkspace
  extend ActiveSupport::Concern

  included do
    before_action :require_user
  end

  private

  def catalog_options
    {
      products: ProductsRepository.new.ordered_for_select.map { |product| product.slice(:id, :name, :sku, :unit) },
      warehouses: WarehousesRepository.new.ordered_for_select.map { |warehouse| warehouse.slice(:id, :name) }
    }
  end

  def page_props(page, records)
    {
      rows: records,
      pagination: page.to_h.except(:records).merge(
        total_pages: page.total_pages,
        next_page: page.next_page,
        previous_page: page.previous_page
      ),
      filters: request.query_parameters
    }
  end

  def form_props(record, fields)
    { values: record.slice(*fields), errors: record.errors.to_hash }
  end

  def balance_props(balance)
    balance.slice(:id, :quantity, :minimum_quantity, :updated_at).merge(
      product: balance.product.slice(:id, :name, :sku, :unit),
      warehouse: balance.warehouse.slice(:id, :name)
    )
  end

  def movement_props(movement)
    movement.slice(:id, :movement_type, :quantity, :note, :created_at).merge(
      product: movement.product.slice(:id, :name, :sku, :unit),
      warehouse: movement.warehouse.slice(:id, :name),
      author: movement.user.email
    )
  end
end
