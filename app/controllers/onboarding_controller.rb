class OnboardingController < ApplicationController
  before_action :authenticate_user!

  def show
    render partial: 'onboarding/modal'
  end

  def update
    case params[:step].to_s
    when 'avatar'
      handle_avatar_step
    when 'naming'
      handle_naming_step
    when 'terms'
      handle_terms_step
    else
      render json: { success: false, message: 'Invalid onboarding step.' }, status: :unprocessable_entity
    end
  end

  private

  def handle_avatar_step
    if params[:skip_avatar].present?
      return render json: { success: true, step: 'naming' }
    end

    if params[:preset_avatar_id].present?
      begin
        current_user.assign_preset_avatar!(params[:preset_avatar_id])
      rescue ArgumentError, ActiveRecord::RecordInvalid => e
        return render json: {
          success: false,
          message: 'Please choose a valid avatar.',
          errors: [e.message]
        }
      end
    elsif params.dig(:user, :avatar).present?
      current_user.avatar.attach(params[:user][:avatar])
      current_user.update!(preset_avatar_id: nil, avatar_url: nil) if current_user.preset_avatar_id.present? || current_user[:avatar_url].present?
    else
      return render json: {
        success: false,
        message: 'Select an avatar, upload a photo, or skip for now.'
      }
    end

    render json: { success: true, step: 'naming' }
  end

  def handle_naming_step
    unless params[:naming_preference].present? && current_user.update(naming_preference: params[:naming_preference])
      return render json: {
        success: false,
        message: 'Please select a naming preference.',
        errors: current_user.errors.full_messages
      }
    end

    render json: { success: true, step: 'terms' }
  end

  def handle_terms_step
    unless params[:terms_agreed].present? && params[:privacy_agreed].present?
      return render json: {
        success: false,
        message: 'Please accept the terms and conditions to continue.'
      }, status: :unprocessable_entity
    end

    update_params = {
      terms_agreed_at: Time.current,
      location_consent: params[:location_consent].present?
    }

    unless current_user.update(update_params)
      return render json: {
        success: false,
        message: current_user.errors.full_messages.join(', ')
      }, status: :unprocessable_entity
    end

    if update_params[:location_consent]
      ip_address = get_real_ip_address
      UpdateUserLocationJob.perform_later(current_user.id, ip_address) if ip_address.present?
    end

    render json: {
      success: true,
      message: 'Welcome to VeriFaith!',
      redirect_url: after_onboarding_path
    }
  end

  def after_onboarding_path
    stored = session[:user_return_to]
    session.delete(:user_return_to)
    stored.presence || feeds_path
  end
end
