class ProductsController < ApplicationController
  include ReactWorkspace

  FIELDS = %i[name sku unit description].freeze
  before_action :set_product, only: %i[show edit update]

  def index
    page = ProductsRepository.new.list(search: params[:search], page: params[:page], per_page: params[:per_page])
    render_react("products", page_props(page, page.records.map { |record| record.slice(:id, *FIELDS) }))
  end

  def show
    render_react("product", { record: @product.slice(:id, *FIELDS) })
  end

  def new
    render_form(Product.new)
  end

  def edit
    render_form(@product)
  end

  def create
    product = ProductsRepository.new.create!(product_params)
    redirect_to product, notice: "Товар создан", status: :see_other
  rescue ActiveRecord::RecordInvalid => error
    render_form(error.record, status: :unprocessable_entity)
  rescue ActiveRecord::RecordNotUnique
    product = Product.new(product_params)
    product.errors.add(:sku, :taken)
    render_form(product, status: :unprocessable_entity)
  end

  def update
    ProductsRepository.new.update!(@product, product_params)
    redirect_to @product, notice: "Товар обновлён", status: :see_other
  rescue ActiveRecord::RecordInvalid => error
    render_form(error.record, status: :unprocessable_entity)
  rescue ActiveRecord::RecordNotUnique
    @product.errors.add(:sku, :taken)
    render_form(@product, status: :unprocessable_entity)
  end

  private

  def render_form(product, status: :ok)
    render_react("product_form", form_props(product, FIELDS).merge(id: product.id), status: status)
  end

  def set_product
    @product = ProductsRepository.new.find(params[:id])
  end

  def product_params
    params.require(:product).permit(*FIELDS)
  end
end
