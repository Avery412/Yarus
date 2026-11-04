# Контроллер только для чтения текущих остатков. Поиск, фильтры и пагинация
# выполняются InventoryBalancesRepository, чтобы SQL не разрастался в контроллере.
class InventoryBalancesController < ApplicationController
  def index
    @pagination = InventoryBalancesRepository.new.list(
      search: params[:search],
      product_id: params[:product_id],
      warehouse_id: params[:warehouse_id],
      page: params[:page],
      per_page: params[:per_page]
    )
    @inventory_balances = @pagination.records
    @products = ProductsRepository.new.ordered_for_select
    @warehouses = WarehousesRepository.new.ordered_for_select
  end

  def show
    @inventory_balance = InventoryBalancesRepository.new.find(params[:id])
  end
end
