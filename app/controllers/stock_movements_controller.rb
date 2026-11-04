# HTTP-контроллер истории и формы складских операций.
# Само изменение количества не выполняется здесь: контроллер собирает входные
# данные, вызывает StockMovements::Create и преобразует ожидаемые ошибки сервиса
# в сообщения формы.
class StockMovementsController < ApplicationController
  before_action :prepare_form_options, only: %i[new create]

  def index
    @pagination = StockMovementsRepository.new.list(
      filters: movement_filter_params,
      page: params[:page],
      per_page: params[:per_page]
    )
    @stock_movements = @pagination.records
  end

  def show
    @stock_movement = StockMovementsRepository.new.find(params[:id])
  end

  def new
    @stock_movement = StockMovement.new
  end

  def create
    attributes = stock_movement_params
    product = ProductsRepository.new.find(attributes[:product_id])
    warehouse = WarehousesRepository.new.find(attributes[:warehouse_id])

    @stock_movement = StockMovements::Create.new(
      product: product,
      warehouse: warehouse,
      user: authenticated_user,
      movement_type: attributes[:movement_type],
      quantity: attributes[:quantity],
      note: attributes[:note]
    ).call

    redirect_to @stock_movement, notice: "Складская операция сохранена"
  rescue ActiveRecord::RecordNotFound
    # Используем тот же безопасный разбор формы, что и для ошибок сервиса:
    # неизвестное значение enum не должно повторно вызвать ArgumentError.
    @stock_movement = build_form_stock_movement
    @stock_movement.errors.add(:base, "Выбранный товар или склад не найден")
    render :new, status: :unprocessable_entity
  rescue StockMovements::Create::Error => error
    @stock_movement = build_form_stock_movement
    @stock_movement.errors.add(:base, error.message)
    render :new, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => error
    @stock_movement = error.record.is_a?(StockMovement) ? error.record : build_form_stock_movement
    @stock_movement.errors.add(:base, error.message) unless error.record.is_a?(StockMovement)
    render :new, status: :unprocessable_entity
  end

  private

  # В фильтры передаются только ожидаемые поля. Репозиторий дополнительно
  # проверяет формат идентификаторов, тип операции и даты перед построением SQL.
  def movement_filter_params
    params.permit(:search, :product_id, :warehouse_id, :movement_type, :start_date, :end_date)
          .to_h.symbolize_keys
  end

  def stock_movement_params
    params.require(:stock_movement).permit(:product_id, :warehouse_id, :movement_type, :quantity, :note)
  end

  def prepare_form_options
    @products = ProductsRepository.new.ordered_for_select
    @warehouses = WarehousesRepository.new.ordered_for_select
  end

  # После ошибки сохраняем введённые пользователем значения в объекте формы.
  # Неизвестный тип операции не присваиваем enum-полю, чтобы не вызвать ошибку enum.
  def build_form_stock_movement
    attributes = stock_movement_params
    movement_type = attributes[:movement_type].to_s
    movement_type = nil unless StockMovement.movement_types.key?(movement_type)

    StockMovement.new(
      product_id: attributes[:product_id],
      warehouse_id: attributes[:warehouse_id],
      movement_type: movement_type,
      quantity: attributes[:quantity],
      note: attributes[:note]
    )
  end

  # Использует текущего пользователя, предоставляемого подключённым механизмом
  # аутентификации. Такой адаптер позволяет сервису явно получать автора операции.
  def authenticated_user
    current_user if respond_to?(:current_user, true)
  end
end
