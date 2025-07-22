class ApplicationController < ActionController::Base
  include Pundit::Authorization

  protect_from_forgery with: :exception
  before_action :configure_permitted_parameters, if: :devise_controller?
  
  # Fix session handling for OAuth
  before_action :set_omniauth_session

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:email, :password, :password_confirmation])
    devise_parameter_sanitizer.permit(:account_update, keys: [:email, :password, :password_confirmation, :current_password])
  end

  private

  def set_omniauth_session
    if request.env['omniauth.auth']
      session[:omniauth] = request.env['omniauth.auth'].except('extra')
    end
  end

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_back(fallback_location: root_path)
  end
end
