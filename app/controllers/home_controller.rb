class HomeController < ApplicationController
  def index
    render_react("home")
  end
end
