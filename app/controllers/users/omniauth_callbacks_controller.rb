class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    user = User.from_omniauth(auth)

    if user.present?
      if user.confirmed?
        sign_out_all_scopes
        flash[:notice] = t 'devise.omniauth_callbacks.success', kind: 'Google'
        sign_in_and_redirect user, event: :authentication
      else
        flash[:alert] = 'You need to confirm your email address before continuing.'
        redirect_to new_user_session_path
      end
    else
      flash[:alert] = t 'devise.omniauth_callbacks.failure', kind: 'Google', reason: "#{auth.info.email} is not authorized."
      redirect_to new_user_session_path
    end
  end

  protected

  def after_omniauth_failure_path_for(_scope)
    new_user_session_path
  end

  private

  def auth
    @auth ||= request.env['omniauth.auth']
  end
end 