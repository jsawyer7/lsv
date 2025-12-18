class ApplicationController < ActionController::Base
  include Pundit::Authorization

  protect_from_forgery with: :exception
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :check_onboarding_completion, if: :user_signed_in?
  before_action :set_languages, if: :user_signed_in?, unless: :admin_controller?
  before_action :set_naming_preferences, if: :user_signed_in?, unless: :admin_controller?
  before_action :update_user_location, if: :user_signed_in?

  # Skip location update for terms acceptance action
  skip_before_action :update_user_location, if: -> { controller_name == 'users' && action_name == 'accept_terms' }

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

  def update_user_location
    # Only update if user has consented to location access
    return unless current_user.location_consent?

    # Only update location if user doesn't have one, or if it's been more than 7 days
    return if current_user.latitude.present? && current_user.longitude.present? &&
              current_user.updated_at > 7.days.ago

    # Get user's real IP address (handles localhost in development)
    ip_address = get_real_ip_address
    return if ip_address.blank?

    # Fetch location from IP (async to avoid blocking request)
    UpdateUserLocationJob.perform_later(current_user.id, ip_address)
  end

  def get_real_ip_address
    # In development, localhost IPs won't work for geolocation
    # So we fetch the user's real public IP from an external service
    ip = request.remote_ip || request.ip

    # Skip localhost/private IPs - they can't be geolocated
    if ip.blank? || ip == '127.0.0.1' || ip == '::1' || ip.start_with?('192.168.') || ip.start_with?('10.') || ip.start_with?('172.')
      # In development, get real public IP from external service
      if Rails.env.development?
        begin
          require 'net/http'
          require 'json'
          uri = URI('https://api.ipify.org?format=json')
          response = Net::HTTP.get_response(uri)
          if response.is_a?(Net::HTTPSuccess)
            data = JSON.parse(response.body)
            return data['ip'] if data['ip'].present?
          end
        rescue => e
          # If external service fails, return nil (location won't be stored)
          return nil
        end
      end
      return nil
    end

    ip
  end
end
