class ApplicationController < ActionController::Base
  include Pundit::Authorization

  protect_from_forgery with: :exception
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :check_onboarding_completion, if: :user_signed_in?
  before_action :set_languages, if: :user_signed_in?, unless: :admin_controller?
  before_action :set_naming_preferences, if: :user_signed_in?, unless: :admin_controller?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:email, :password, :password_confirmation])
    devise_parameter_sanitizer.permit(:account_update, keys: [:email, :password, :password_confirmation, :current_password])
  end

  private

  def check_onboarding_completion
    return if controller_name == 'onboarding' || controller_name == 'devise'

    unless current_user.onboarding_complete?
      @show_onboarding_modal = true
    end
  end

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_back(fallback_location: root_path)
  end

  def set_languages
    @languages = Language.all.order(:name)
  end

  def set_naming_preferences
    @naming_preferences = [
      {
        id: 'greco_latin_english',
        name: 'English',
        description: 'English names (Jesus, Messiah, etc.)',
        languages: ['English']
      },
      {
        id: 'hebrew_aramaic',
        name: 'Hebrew/Aramaic',
        description: 'Traditional Hebrew and Aramaic names (Yeshua, Mashiach, etc.)',
        languages: ['Hebrew', 'Aramaic']
      },
      {
        id: 'arabic',
        name: 'Arabic',
        description: 'Arabic names (Isa, Masih, etc.)',
        languages: ['Arabic']
      }
    ]
  end

  def admin_controller?
    controller_path.start_with?('admin/')
  end
end
