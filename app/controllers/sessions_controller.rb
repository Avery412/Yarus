class SessionsController < ApplicationController
  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { render_react("sign_in", { error: "Слишком много попыток. Попробуйте через несколько минут." }, status: :too_many_requests) }

  def new
    return redirect_to inventory_balances_path if current_user

    render_react("sign_in")
  end

  def create
    email = params[:email].to_s.strip.downcase
    user = User.authenticate_by(email: email, password: params[:password].to_s)

    if user
      return_to = session[:return_to]
      reset_session
      session[:user_id] = user.id
      redirect_to(allowed_return_path(return_to), status: :see_other)
    else
      render_react("sign_in", { email: email, error: "Проверьте электронную почту и пароль" }, status: :unprocessable_entity)
    end
  end

  def destroy
    reset_session
    redirect_to root_path, status: :see_other
  end

  private

  def allowed_return_path(path)
    return path if path&.match?(%r{\A/(products|warehouses|inventory_balances|stock_movements)(?:[/?]|\z)})

    inventory_balances_path
  end
end
