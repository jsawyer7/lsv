class FactsController < ApplicationController
  layout 'dashboard'

  def index
    @filters = %w[all my_facts]
    @current_filter = params[:filter] || 'all'
    @search = params[:search]
    @facts = Claim.published_facts.includes(:user)
    @facts = @facts.where('content ILIKE ?', "%#{@search}%") if @search.present?
    @facts = @facts.order(created_at: :desc).limit(10)

    # Dynamic data for sidebar sections
    setup_sidebar_data
  end

  def infinite
    page = params[:page].to_i
    search = params[:search]
    facts = Claim.where.not(state: 'draft')
    facts = facts.where('content ILIKE ?', "%#{search}%") if search.present?
    facts = facts.order(created_at: :desc).offset(10 * page).limit(10)
    render json: {
      facts: facts.map { |fact| render_to_string(partial: 'fact_card', formats: [:html], locals: { fact: fact }) },
      has_more: facts.size == 10
    }
  end

  private

  def setup_sidebar_data
    # Who to Follow: Get users with most followers, excluding current user
    if user_signed_in?
      # Get users that current user is not already following
      following_ids = current_user.following.pluck(:id)
      following_ids << current_user.id

      @who_to_follow = User.where.not(id: following_ids)
                          .left_joins(:reverse_follows)
                          .group('users.id')
                          .order('COUNT(follows.id) DESC')
                          .limit(3)
    else
      # For non-logged in users, show users with most followers
      @who_to_follow = User.left_joins(:reverse_follows)
                          .group('users.id')
                          .order('COUNT(follows.id) DESC')
                          .limit(3)
    end

    # Top Picks: Get most recent published facts/theories
    @top_picks = Claim.published_facts
                     .includes(:user)
                     .order(created_at: :desc)
                     .limit(3)
  end
end
