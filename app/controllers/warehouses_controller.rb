class WarehousesController < ApplicationController
  include ReactWorkspace

  FIELDS = %i[name address description].freeze
  before_action :set_warehouse, only: %i[show edit update]

  def index
    page = WarehousesRepository.new.list(search: params[:search], page: params[:page], per_page: params[:per_page])
    render_react("warehouses", page_props(page, page.records.map { |record| record.slice(:id, *FIELDS) }))
  end

  def show
    render_react("warehouse", { record: @warehouse.slice(:id, *FIELDS) })
  end

  def new
    render_form(Warehouse.new)
  end

  def edit
    render_form(@warehouse)
  end

  def create
    warehouse = WarehousesRepository.new.create!(warehouse_params)
    redirect_to warehouse, notice: "Склад создан", status: :see_other
  rescue ActiveRecord::RecordInvalid => error
    render_form(error.record, status: :unprocessable_entity)
  end

  def update
    WarehousesRepository.new.update!(@warehouse, warehouse_params)
    redirect_to @warehouse, notice: "Склад обновлён", status: :see_other
  rescue ActiveRecord::RecordInvalid => error
    render_form(error.record, status: :unprocessable_entity)
  end

  private

  def render_form(warehouse, status: :ok)
    render_react("warehouse_form", form_props(warehouse, FIELDS).merge(id: warehouse.id), status: status)
  end

  def set_warehouse
    @warehouse = WarehousesRepository.new.find(params[:id])
  end

  def warehouse_params
    params.require(:warehouse).permit(*FIELDS)
  end
end
