class UsersController < ApplicationController
  before_action :authenticate_user!
  layout 'dashboard'

  def profile
    @user = User.find(params[:id])
    @claims = @user.claims.order(created_at: :desc).page(params[:page]).per(10)
    @followers = @user.followers.limit(5)
    @following = @user.following.limit(5)
  end

  def profile_infinite
    user = User.find(params[:id])
    page = params[:page].to_i > 0 ? params[:page].to_i : 1
    per_page = 10
    claims = user.claims.includes(:likes).order(created_at: :desc).offset((page - 1) * per_page).limit(per_page)
    # Note: Comments will be filtered in the view using visible_to scope
    render json: {
      claims: claims.map { |claim|
        user_like = current_user ? claim.likes.find_by(user: current_user) : nil
        claim.as_json(only: [:id, :created_at, :user_id]).merge(
          content: claim.content_for_user(current_user),
          likes_count: claim.likes.count,
          user_liked: user_like.present?,
          like_id: user_like&.id,
          user: {
            full_name: claim.user&.full_name,
            email: claim.user&.email
          }
        )
      },
      has_more: claims.size == per_page
    }
  end

  def accept_terms
    # Accept all terms when single checkbox is checked
    unless params[:terms_agreed].present? && params[:privacy_agreed].present?
      render json: { success: false, message: 'Please accept the terms and conditions' }, status: :unprocessable_entity
      return
    end

    update_params = {
      terms_agreed_at: Time.current,
      location_consent: params[:location_consent].present?
    }

    if current_user.update(update_params)
      # If location consent was given, trigger location update
      if update_params[:location_consent]
        ip_address = get_real_ip_address
        UpdateUserLocationJob.perform_later(current_user.id, ip_address) if ip_address.present?
      end

      render json: { success: true, message: 'Terms accepted successfully' }
    else
      render json: { success: false, message: current_user.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  end

  private

  def get_real_ip_address
    # In development, localhost IPs won't work for geolocation
    # So we fetch the user's real public IP from an external service
    ip = request.remote_ip || request.ip

    # Skip localhost IPs - they can't be geolocated
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
