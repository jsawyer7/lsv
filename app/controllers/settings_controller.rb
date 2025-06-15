class SettingsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user
  layout 'dashboard'

  def edit
    # @user is set by before_action
  end

  def update
    # @user is set by before_action
    # Remove avatar if requested
    if params[:remove_avatar] == "true"
      @user.avatar.purge
    elsif params[:user] && params[:user][:avatar]
      @user.avatar.attach(params[:user][:avatar])
    end

    if params[:user] && @user.update(user_params.except(:avatar))
      redirect_to edit_settings_path, notice: 'Profile updated successfully.'
    else
      render :edit
    end
  end

  def notifications
    render :notifications
  end

  private
  def set_user
    @user = current_user
  end

  def user_params
    params.require(:user).permit(:full_name, :phone, :email, :about, :avatar, :avatar_cache, :remove_avatar)
  end
end 