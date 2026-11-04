require "bigdecimal"

module StockMovements
  # Сценарий прихода или расхода. Сервис координирует репозитории и открывает
  # одну транзакцию, чтобы изменение текущего остатка и запись истории всегда
  # сохранялись вместе либо вместе отменялись.
  class Create
    MAX_QUANTITY = BigDecimal("999999999.999")
    SUPPORTED_TYPES = %w[receipt issue].freeze

    class Error < StandardError; end
    class InvalidQuantityError < Error; end
    class InvalidMovementTypeError < Error; end
    class InvalidReferenceError < Error; end
    class InsufficientStockError < Error; end
    class BalanceLimitExceededError < Error; end

    def initialize(product:, warehouse:, user:, movement_type:, quantity:, note: nil,
                   inventory_balances_repository: InventoryBalancesRepository.new,
                   stock_movements_repository: StockMovementsRepository.new)
      @product = product
      @warehouse = warehouse
      @user = user
      @movement_type = movement_type.to_s
      @quantity = normalize_quantity(quantity)
      @note = note
      @inventory_balances_repository = inventory_balances_repository
      @stock_movements_repository = stock_movements_repository
    end

    def call
      validate_references!
      validate_movement_type!

      stock_movement = nil

      # Блокировка строки остатка внутри этой транзакции сериализует операции
      # для одной пары «товар + склад». Ошибка на любом шаге откатывает и баланс,
      # и запись истории, поэтому частично выполненной операции не останется.
      StockMovement.transaction do
        balance = @inventory_balances_repository.find_or_create_locked!(
          product: @product,
          warehouse: @warehouse
        )

        new_balance_quantity = calculate_new_balance(balance.quantity)
        @inventory_balances_repository.update_quantity!(balance, quantity: new_balance_quantity)

        # create! вызывается с именованными атрибутами. ApplicationRepository
        # принимает их явно через **keyword_attributes и передаёт модели Hash.
        stock_movement = @stock_movements_repository.create!(
          product: @product,
          warehouse: @warehouse,
          user: @user,
          movement_type: @movement_type,
          quantity: @quantity,
          note: @note
        )
      end

      stock_movement
    end

    private

    # Преобразует ввод в BigDecimal, чтобы не использовать неточную двоичную
    # арифметику Float для складских количеств. Точность ограничена тремя знаками.
    def normalize_quantity(value)
      amount = BigDecimal(value.to_s)
      unless amount.finite? && amount.positive? && amount <= MAX_QUANTITY
        raise InvalidQuantityError, "Количество должно быть больше нуля и не превышать 999999999.999"
      end

      unless (amount * 1_000).frac.zero?
        raise InvalidQuantityError, "Количество можно указывать максимум с тремя знаками после запятой"
      end

      amount
    rescue ArgumentError, TypeError
      raise InvalidQuantityError, "Укажите корректное числовое количество"
    end

    def validate_references!
      return if @product&.persisted? && @warehouse&.persisted? && @user&.persisted?

      raise InvalidReferenceError, "Для операции нужны сохранённые товар, склад и пользователь"
    end

    def validate_movement_type!
      return if SUPPORTED_TYPES.include?(@movement_type)

      raise InvalidMovementTypeError, "Тип операции должен быть receipt или issue"
    end

    def calculate_new_balance(current_quantity)
      if @movement_type == "receipt"
        new_quantity = current_quantity + @quantity
        if new_quantity > MAX_QUANTITY
          raise BalanceLimitExceededError, "Итоговый остаток не может превышать 999999999.999"
        end

        new_quantity
      else
        if current_quantity < @quantity
          raise InsufficientStockError, "Недостаточно товара на складе для выполнения расхода"
        end

        current_quantity - @quantity
      end
    end
  end
end
