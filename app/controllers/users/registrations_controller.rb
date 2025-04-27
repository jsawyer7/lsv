# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
  before_action :configure_sign_up_params, only: [:create]

  # GET /resource/sign_up
  def new
    self.resource = User.new
  end

  # POST /resource
  def create
    self.resource = User.new(sign_up_params)

    if resource.save
      if resource.active_for_authentication?
        flash[:notice] = "Welcome! You have signed up successfully."
        sign_in(resource_name, resource)
        respond_with resource, location: after_sign_up_path_for(resource)
      else
        flash[:notice] = "A confirmation email has been sent to your email address. Please check your email and click on the confirmation link."
        expire_data_after_sign_in!
        respond_with resource, location: after_inactive_sign_up_path_for(resource)
      end
    else
      clean_up_passwords resource
      flash[:alert] = resource.errors.full_messages.first
      respond_with resource
    end
  end

  protected

  def configure_sign_up_params
    devise_parameter_sanitizer.permit(:sign_up, keys: [:email, :password, :password_confirmation])
  end

  def sign_up_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end

  def after_sign_up_path_for(resource)
    new_user_confirmation_path
  end

  def after_inactive_sign_up_path_for(resource)
    new_user_confirmation_path
  end
end
