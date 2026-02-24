class FeedsController < ApplicationController
  before_action :authenticate_user!
  layout 'dashboard'
  def index
    # Initial page load, render the feed view
  end

  def infinite
    page = params[:page].to_i > 0 ? params[:page].to_i : 1
    per_page = page == 1 ? 30 : 20

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
          {
            html: render_to_string(partial: 'shared/feed_card', locals: { fact: claim }, formats: [:html]),
            id: claim.id,
            created_at: claim.created_at
          }
        else
          # Reshared item
          share = item[:data]
          shareable = share.shareable

          case shareable
          when Claim
            {
              html: render_to_string(partial: 'shared/feed_card_reshare', locals: { share: share, fact: shareable }, formats: [:html]),
              id: shareable.id,
              created_at: share.created_at
            }
          when Theory
            # For theories, we can handle separately if needed
            nil
          else
            nil
          end
        end
      }.compact,
      has_more: all_items.size == per_page
    }
  end
end
