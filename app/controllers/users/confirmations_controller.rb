# frozen_string_literal: true

class Users::ConfirmationsController < Devise::ConfirmationsController
  # GET /resource/confirmation/new
  def new
    self.resource = resource_class.new
  end

  # POST /resource/confirmation
  def create
    self.resource = resource_class.send_confirmation_instructions(resource_params)

    if successfully_sent?(resource)
      flash[:notice] = "Confirmation instructions have been sent to your email."
      redirect_to new_user_session_path
    else
      flash[:alert] = resource.errors.full_messages.first || "Could not send confirmation instructions."
      respond_with(resource)
    end
  end

  # GET /resource/confirmation?confirmation_token=abcdef
  def show
    self.resource = resource_class.confirm_by_token(params[:confirmation_token])

    if resource.errors.empty?
      flash[:notice] = "Your email address has been successfully confirmed."
      redirect_to new_user_session_path
    else
      flash[:alert] = resource.errors.full_messages.first || "Could not confirm your account. Please try again."
      redirect_to new_user_confirmation_path
    end
  end

  protected

  def after_confirmation_path_for(resource_name, resource)
    sign_in(resource)
    flash[:notice] = "Your account has been confirmed. You are now signed in."
    root_path
  end
end 