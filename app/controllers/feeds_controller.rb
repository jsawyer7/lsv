class FeedsController < ApplicationController
  before_action :authenticate_user!
  layout 'dashboard'
  def index
    # Initial page load, render the feed view
  end

  def infinite
    page = params[:page].to_i > 0 ? params[:page].to_i : 1
    per_page = 20

    # Get published facts
    claims = Claim.published_facts.includes(:user, :likes).order(created_at: :desc).offset((page - 1) * per_page).limit(per_page)

    # Get reshared items (shares with recipient_id = nil)
    reshared_shares = Share.reshared
                           .includes(shareable: [:user, :likes], user: [])
                           .order(created_at: :desc)
                           .offset((page - 1) * per_page)
                           .limit(per_page)

    # Combine and sort by created_at
    all_items = []

    claims.each do |claim|
      all_items << {
        type: 'claim',
        created_at: claim.created_at,
        data: claim
      }
    end

    reshared_shares.each do |share|
      all_items << {
        type: 'reshared',
        created_at: share.created_at,
        data: share
      }
    end

    # Sort by created_at descending
    all_items.sort_by! { |item| -item[:created_at].to_i }
    all_items = all_items.first(per_page)

    render json: {
      claims: all_items.map { |item|
        if item[:type] == 'claim'
          claim = item[:data]
          user_like = current_user ? claim.likes.find_by(user: current_user) : nil
          # Filter comments to only show those visible to current user (peer network only)
          visible_comments = claim.comments.visible_to(current_user).recent
          comments_data = visible_comments.map do |comment|
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
            comments_count: claim.comments.visible_to(current_user).count,
            comments: comments_data,
            user: {
              full_name: claim.user&.full_name,
              email: claim.user&.email
            },
            current_user: {
              avatar_url: current_user&.avatar_url
            },
            is_reshared: false
          )
        else
          # Reshared item
          share = item[:data]
          shareable = share.shareable

          case shareable
          when Claim
            user_like = current_user ? shareable.likes.find_by(user: current_user) : nil
            visible_comments = shareable.comments.visible_to(current_user).recent
            comments_data = visible_comments.map do |comment|
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

            shareable.as_json(only: [:id, :created_at, :user_id]).merge(
              content: shareable.content_for_user(current_user),
              likes_count: shareable.likes.count,
              user_liked: user_like.present?,
              like_id: user_like&.id,
              comments_count: shareable.comments.visible_to(current_user).count,
              comments: comments_data,
              user: {
                full_name: shareable.user&.full_name,
                email: shareable.user&.email
              },
              current_user: {
                avatar_url: current_user&.avatar_url
              },
              is_reshared: true,
              reshared_by: {
                full_name: share.user&.full_name,
                email: share.user&.email,
                avatar_url: share.user&.avatar_url
              },
              reshare_message: share.message
            )
          when Theory
            user_like = current_user ? shareable.likes.find_by(user: current_user) : nil
            shareable.as_json(only: [:id, :title, :description, :created_at]).merge(
              likes_count: shareable.likes.count,
              user_liked: user_like.present?,
              like_id: user_like&.id,
              user: {
                full_name: shareable.user&.full_name,
                email: shareable.user&.email
              },
              is_reshared: true,
              reshared_by: {
                full_name: share.user&.full_name,
                email: share.user&.email,
                avatar_url: share.user&.avatar_url
              },
              reshare_message: share.message
            )
          else
            nil
          end
        end
      }.compact,
      has_more: all_items.size == per_page
    }
  end
end
