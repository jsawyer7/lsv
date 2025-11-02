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
    claims = user.claims.order(created_at: :desc).offset((page - 1) * per_page).limit(per_page)
    render json: {
      claims: claims.map { |claim|
        claim.as_json(only: [:id, :created_at, :user_id]).merge(
          content: claim.content_for_user(current_user),
          user: {
            full_name: claim.user&.full_name,
            email: claim.user&.email
          }
        )
      },
      has_more: claims.size == per_page
    }
  end
end
