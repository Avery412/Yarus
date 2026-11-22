class InventoryBalancesController < ApplicationController
  include ReactWorkspace

  def index
    page = InventoryBalancesRepository.new.list(
      search: params[:search], product_id: params[:product_id], warehouse_id: params[:warehouse_id],
      page: params[:page], per_page: params[:per_page]
    )
    render_react("inventory_balances", page_props(page, page.records.map { |balance| balance_props(balance) }).merge(catalog_options))
  end

  def show
    balance = InventoryBalancesRepository.new.find(params[:id])
    render_react("inventory_balance", { record: balance_props(balance) })
  end
end
