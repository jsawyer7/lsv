class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  skip_before_action :verify_authenticity_token

  def google_oauth2
    @user = User.from_omniauth(request.env["omniauth.auth"])

    if @user.persisted?
      sign_in @user
      flash[:notice] = I18n.t "devise.omniauth_callbacks.success", kind: "Google"
      redirect_to feeds_path
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

  def twitter
    @user = User.from_omniauth(request.env["omniauth.auth"])

    if @user.persisted?
      sign_in @user
      flash[:notice] = I18n.t "devise.omniauth_callbacks.success", kind: "X"
      redirect_to feeds_path
    else
      session["devise.twitter_data"] = request.env["omniauth.auth"].except(:extra)
      flash[:alert] = @user.errors.full_messages.join(", ")
      redirect_to new_user_registration_url
    end
  rescue StandardError => e
    Rails.logger.error "X OAuth Error: #{e.message}\n#{e.backtrace.join("\n")}"
    flash[:alert] = "An error occurred while authenticating with X. Please try again."
    redirect_to new_user_session_path
  end

  def failure
    error_message = error_message_for_failure
    Rails.logger.info "OAuth Failure - Provider: #{request.env['omniauth.error.strategy']&.name}, Error Type: #{request.env['omniauth.error.type']}, Error: #{request.env['omniauth.error']&.message}"
    flash[:alert] = error_message
    redirect_to new_user_session_path
  end
   def facebook
    @user = User.from_omniauth(request.env["omniauth.auth"])

    if @user.persisted?
      sign_in @user
      flash[:notice] = I18n.t "devise.omniauth_callbacks.success", kind: "Facebook"
      redirect_to feeds_path
    else
      session["devise.facebook_data"] = request.env["omniauth.auth"].except(:extra)
      flash[:alert] = @user.errors.full_messages.join(", ")
      redirect_to new_user_registration_url
    end
  rescue StandardError => e
    Rails.logger.error "Facebook OAuth Error: #{e.message}\n#{e.backtrace.join("\n")}"
    flash[:alert] = "An error occurred while authenticating with Facebook. Please try again."
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
    strategy = request.env["omniauth.error.strategy"]
    provider = if strategy&.name
                 case strategy.name
                 when 'google_oauth2'
                   'Google'
                 when 'facebook'
                   'Facebook'
                 when 'twitter'
                   'X'
                 else
                   strategy.name.titleize
                 end
               else
                 "OAuth provider"
               end

    case error_type
    when :invalid_credentials
      "Invalid credentials. Please try again."
    when :access_denied
      "Access was denied. Please try again."
    when :invalid_response
      "There was a problem with the response from #{provider}. Please try again."
    when :csrf_detected
      Rails.logger.error "OAuth2 CSRF Error: #{error&.message}"
      "Security verification failed. Please try again."
    when :timeout
      "Authentication request timed out. Please try again."
    when :service_unavailable
      "#{provider} service is temporarily unavailable. Please try again later."
    else
      if error.is_a?(OmniAuth::Strategies::OAuth2::CallbackError)
        Rails.logger.error "OAuth2 Callback Error: #{error.message}"
        "Authentication error: #{error.message}. Please try again."
      else
        Rails.logger.error "Unknown OAuth2 Error: #{error&.message}"
        "Could not authenticate you from #{provider}. Please try again."
      end
    end
  end
end 