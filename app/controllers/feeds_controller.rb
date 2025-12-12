class FeedsController < ApplicationController
  before_action :authenticate_user!
  layout 'dashboard'
  def index
    # Initial page load, render the feed view
  end

  def infinite
    page = params[:page].to_i > 0 ? params[:page].to_i : 1
    per_page = 20
    claims = Claim.published_facts.includes(:user, :likes).order(created_at: :desc).offset((page - 1) * per_page).limit(per_page)
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
end
