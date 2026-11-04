# Общая часть репозиториев: поиск записей, создание/обновление и пагинация.
# Предметные репозитории наследуются от этого класса и содержат запросы
# только для своей модели.
class ApplicationRepository
  DEFAULT_PER_PAGE = 20
  MAX_PER_PAGE = 100

  # Единый объект результата пагинации. Контроллер получает записи и данные
  # для навигации, не зная деталей построения SQL-запроса.
  Page = Struct.new(:records, :page, :per_page, :total_count, keyword_init: true) do
    def total_pages
      return 0 if total_count.zero?

      # Целочисленное деление не теряет точность на больших объёмах данных.
      (total_count + per_page - 1) / per_page
    end

    def next_page
      page < total_pages ? page + 1 : nil
    end

    def previous_page
      page > 1 ? page - 1 : nil
    end
  end

  def initialize(model_class)
    @model_class = model_class
  end

  def find(id)
    @model_class.find(id)
  end

  # Поддерживает оба распространённых способа вызова:
  # create!({ name: "..." }) и create!(name: "..."). Это важно, поскольку
  # Ruby разделяет позиционные и именованные аргументы.
  def create!(attributes = nil, **keyword_attributes)
    attributes = (attributes || {}).to_h.merge(keyword_attributes)
    @model_class.create!(attributes)
  end

  def update!(record, attributes = nil, **keyword_attributes)
    attributes = (attributes || {}).to_h.merge(keyword_attributes)
    record.update!(attributes)
    record
  end

  private

  def paginate_relation(scope, page:, per_page:)
    current_page = positive_integer(page, fallback: 1)
    page_size = positive_integer(per_page, fallback: DEFAULT_PER_PAGE).clamp(1, MAX_PER_PAGE)
    total_count = scope.count

    Page.new(
      records: scope.limit(page_size).offset((current_page - 1) * page_size),
      page: current_page,
      per_page: page_size,
      total_count: total_count
    )
  end

  # Преобразует пользовательский параметр в положительное целое число.
  # Некорректные и отрицательные значения заменяются безопасным значением.
  def positive_integer(value, fallback: nil)
    number = Integer(value)
    number.positive? ? number : fallback
  rescue ArgumentError, TypeError
    fallback
  end

  def safe_id(value)
    positive_integer(value, fallback: nil)
  end

  # Убирает пробелы и превращает пустую строку в nil, чтобы не добавлять
  # бессмысленный LIKE-фильтр к запросу.
  def search_term(value)
    value.to_s.strip.presence
  end
end
