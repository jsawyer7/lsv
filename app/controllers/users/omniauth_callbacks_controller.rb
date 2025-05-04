class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  skip_before_action :verify_authenticity_token

  def google_oauth2
    @user = User.from_omniauth(request.env["omniauth.auth"])

    if @user.persisted?
      sign_in @user
      flash[:notice] = I18n.t "devise.omniauth_callbacks.success", kind: "Google"
      redirect_to root_path
    else
      session["devise.google_data"] = request.env["omniauth.auth"].except(:extra)
      flash[:alert] = @user.errors.full_messages.join(", ")
      redirect_to new_user_registration_url
    end
  rescue StandardError => e
    Rails.logger.error "Google OAuth2 Error: #{e.message}\n#{e.backtrace.join("\n")}"
    flash[:alert] = "An error occurred while authenticating with Google. Please try again."
    redirect_to new_user_session_path
  end

  def failure
    error_message = error_message_for_failure
    flash[:alert] = error_message
    redirect_to new_user_session_path
  end

  protected

  def after_omniauth_failure_path_for(_scope)
    new_user_session_path
  end

  private

  def error_message_for_failure
    error_type = request.env["omniauth.error.type"]
    error = request.env["omniauth.error"]

    case error_type
    when :invalid_credentials
      "Invalid credentials. Please try again."
    when :access_denied
      "Access was denied. Please try again."
    when :invalid_response
      "There was a problem with the response from Google. Please try again."
    when :csrf_detected
      Rails.logger.error "OAuth2 CSRF Error: #{error&.message}"
      "Security verification failed. Please try again."
    else
      if error.is_a?(OmniAuth::Strategies::OAuth2::CallbackError)
        Rails.logger.error "OAuth2 Callback Error: #{error.message}"
        "Authentication error: #{error.message}. Please try again."
      else
        Rails.logger.error "Unknown OAuth2 Error: #{error&.message}"
        "Could not authenticate you from Google. Please try again."
      end
    end
  end
end 