class OnboardingController < ApplicationController
  before_action :authenticate_user!

  def show
    # Show the onboarding modal content
    # @languages is set by ApplicationController
    render partial: 'onboarding/modal'
  end

  def update
    # Store the naming preference using enum
    if current_user.update(naming_preference: params[:naming_preference])
      render json: {
        success: true,
        message: 'Welcome! Your preferences have been set.',
        redirect_url: feeds_path
      }
    else
      render json: {
        success: false,
        message: 'Please select a naming preference.',
        errors: current_user.errors.full_messages
      }
    end
  end
end
