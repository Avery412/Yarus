# Принимает HTTP-запросы для каталога товаров. Правила поиска и доступа к данным
# находятся в ProductsRepository, а контроллер отвечает за параметры и ответы HTTP.
class ProductsController < ApplicationController
  before_action :set_product, only: %i[show edit update]

  def index
    @pagination = ProductsRepository.new.list(
      search: params[:search],
      page: params[:page],
      per_page: params[:per_page]
    )
    @products = @pagination.records
  end

  def show; end

  def new
    @product = Product.new
  end

  def create
    @product = ProductsRepository.new.create!(product_params)
    redirect_to @product, notice: "Товар создан"
  rescue ActiveRecord::RecordInvalid => error
    @product = error.record
    render :new, status: :unprocessable_entity
  end

  def edit; end

  def update
    ProductsRepository.new.update!(@product, product_params)
    redirect_to @product, notice: "Товар обновлён"
  rescue ActiveRecord::RecordInvalid => error
    @product = error.record
    render :edit, status: :unprocessable_entity
  end

  private

  def set_product
    @product = ProductsRepository.new.find(params[:id])
  end

  # Разрешён только явно перечисленный набор полей; параметры запроса не могут
  # напрямую менять служебные атрибуты модели.
  def product_params
    params.require(:product).permit(:name, :sku, :description, :unit)
  end
end
