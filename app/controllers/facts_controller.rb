class FactsController < ApplicationController
  before_action :authenticate_user!
  layout 'dashboard'

  def index
    @top_facts = Claim.published_facts
                      .left_joins(:likes)
                      .group('claims.id')
                      .order(Arel.sql('COUNT(likes.id) DESC'))
                      .limit(2)
                      .includes(:user)
  end

  def infinite
    page = params[:page].to_i > 0 ? params[:page].to_i : 1
    per_page = page == 1 ? 30 : 20
    offset = (page - 1) * per_page
    facts = Claim.published_facts.includes(:user, :likes)
    facts = facts.where(user_id: current_user.id) if params[:filter] == 'my_facts'
    facts = facts.where('content ILIKE ?', "%#{params[:search]}%") if params[:search].present?
    facts = facts.order(created_at: :desc).offset(offset).limit(per_page)
    render json: {
      claims: facts.map { |fact|
        {
          html: render_to_string(partial: 'shared/feed_card', locals: { fact: fact }, formats: [:html]),
          id: fact.id,
          created_at: fact.created_at
        }
      },
      has_more: facts.size == per_page
    }
  end
end
