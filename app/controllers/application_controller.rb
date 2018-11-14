class ApplicationController < ActionController::Base
  before_action :authorized

  def login_user(user)
    session[:user_id] = user.id
  end

  def current_user
    @user = User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def logged_in?
    !!current_user
  end
  helper_method :logged_in?

  def authorized
    redirect_to login_path unless logged_in?
  end
end
