class FeedsController < ApplicationController
  before_action :authenticate_user!
  layout 'dashboard'
  def index
    # Initial page load, render the feed view
  end

  def infinite
    page = params[:page].to_i > 0 ? params[:page].to_i : 1
    per_page = 20
    claims = Claim.includes(:user).order(created_at: :desc).offset((page - 1) * per_page).limit(per_page)
    render json: {
      claims: claims.map { |claim|
        claim.as_json(only: [:id, :content, :created_at, :user_id]).merge(
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