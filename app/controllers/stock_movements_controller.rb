class StockMovementsController < ApplicationController
  include ReactWorkspace

  FIELDS = %i[product_id warehouse_id movement_type quantity note].freeze
  FILTERS = %i[search product_id warehouse_id movement_type start_date end_date].freeze

  def index
    page = StockMovementsRepository.new.list(
      filters: params.permit(*FILTERS).to_h.symbolize_keys, page: params[:page], per_page: params[:per_page]
    )
    render_react("stock_movements", page_props(page, page.records.map { |movement| movement_props(movement) }).merge(catalog_options))
  end

  def show
    movement = StockMovementsRepository.new.find(params[:id])
    render_react("stock_movement", { record: movement_props(movement) })
  end

  def new
    render_form(params.permit(:product_id, :warehouse_id, :movement_type, :quantity).to_h)
  end

  def create
    attributes = params.require(:stock_movement).permit(*FIELDS).to_h.symbolize_keys
    movement = StockMovements::Create.new(
      product: ProductsRepository.new.find(attributes[:product_id]),
      warehouse: WarehousesRepository.new.find(attributes[:warehouse_id]),
      user: current_user,
      movement_type: attributes[:movement_type],
      quantity: attributes[:quantity].to_s.strip.tr(",", "."),
      note: attributes[:note]
    ).call

    redirect_to movement, notice: "Складская операция сохранена", status: :see_other
  rescue ActiveRecord::RecordNotFound
    render_form(attributes, errors: { base: ["Выбранный товар или склад не найден"] }, status: :unprocessable_entity)
  rescue StockMovements::Create::Error => error
    render_form(attributes, errors: { base: [error.message] }, status: :unprocessable_entity)
  rescue ActiveRecord::RecordInvalid => error
    render_form(attributes, errors: error.record.errors.to_hash, status: :unprocessable_entity)
  end

  private

  def render_form(values, errors: {}, status: :ok)
    render_react("movement_form", catalog_options.merge(values: values, errors: errors), status: status)
  end
end
