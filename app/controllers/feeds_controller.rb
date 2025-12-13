class FeedsController < ApplicationController
  before_action :authenticate_user!
  layout 'dashboard'
  def index
    # Initial page load, render the feed view
  end

  def infinite
    page = params[:page].to_i > 0 ? params[:page].to_i : 1
    per_page = 20
    claims = Claim.published_facts.includes(:user, :likes, comments: [:user, :likes]).order(created_at: :desc).offset((page - 1) * per_page).limit(per_page)
    render json: {
      claims: claims.map { |claim|
        user_like = current_user ? claim.likes.find_by(user: current_user) : nil
        comments_data = claim.comments.recent.limit(3).map do |comment|
          {
            id: comment.id,
            content: comment.content,
            user: {
              full_name: comment.user&.full_name,
              email: comment.user&.email,
              avatar_url: comment.user&.avatar_url
            },
            created_at: comment.created_at,
            likes_count: comment.likes.count
          }
        end
        claim.as_json(only: [:id, :created_at, :user_id]).merge(
          content: claim.content_for_user(current_user),
          likes_count: claim.likes.count,
          user_liked: user_like.present?,
          like_id: user_like&.id,
          comments_count: claim.comments.count,
          comments: comments_data,
          user: {
            full_name: claim.user&.full_name,
            email: claim.user&.email
          },
          current_user: {
            avatar_url: current_user&.avatar_url
          }
        )
      },
      has_more: claims.size == per_page
    }
  end
end
