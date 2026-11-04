# HTTP-контроллер складов. Все выборки и изменения записей делегируются
# WarehousesRepository, а здесь остаются только сценарии запросов и ответов.
class WarehousesController < ApplicationController
  before_action :set_warehouse, only: %i[show edit update]

  def index
    @pagination = WarehousesRepository.new.list(
      search: params[:search],
      page: params[:page],
      per_page: params[:per_page]
    )
    @warehouses = @pagination.records
  end

  def show; end

  def new
    @warehouse = Warehouse.new
  end

  def create
    @warehouse = WarehousesRepository.new.create!(warehouse_params)
    redirect_to @warehouse, notice: "Склад создан"
  rescue ActiveRecord::RecordInvalid => error
    @warehouse = error.record
    render :new, status: :unprocessable_entity
  end

  def edit; end

  def update
    WarehousesRepository.new.update!(@warehouse, warehouse_params)
    redirect_to @warehouse, notice: "Склад обновлён"
  rescue ActiveRecord::RecordInvalid => error
    @warehouse = error.record
    render :edit, status: :unprocessable_entity
  end

  private

  def set_warehouse
    @warehouse = WarehousesRepository.new.find(params[:id])
  end

  def warehouse_params
    params.require(:warehouse).permit(:name, :address, :description)
  end
end
