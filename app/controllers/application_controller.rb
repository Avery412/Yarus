class ApplicationController < ActionController::Base
  rescue_from ActiveRecord::RecordNotFound do
    render_react("not_found", status: :not_found)
  end

  private

  def current_user
    return @current_user if defined?(@current_user)

    @current_user = User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def require_user
    return if current_user

    session[:return_to] = request.fullpath if request.get?
    redirect_to new_session_path, alert: "Войдите, чтобы открыть складской учёт", status: :see_other
  end

  def render_react(screen, props = {}, status: :ok)
    @react_data = {
      screen: screen, props: props,
      user: current_user&.slice(:email, :role),
      notice: flash[:notice], alert: flash[:alert],
      warehouse_image: helpers.image_path("yarus-warehouse.png"),
      icons: %w[brick tile laminate dry-mix timber insulation].index_with { |name| helpers.image_path("material-#{name}.svg") }
    }
    render "workspace/screen", status: status
  end
end
