class DashboardController < ApplicationController
  before_action :authenticate_user!
  layout 'dashboard'

  def index
    @claims = current_user.claims.order(created_at: :desc).page(params[:page]).per(12)
    @claims = @claims.where('content ILIKE ?', "%#{params[:search]}%") if params[:search].present?
  end

  def veritalk
    @conversations = current_user.conversations.order(updated_at: :desc).limit(50)
  end

  def claims
    @filter = params[:filter].presence || 'claims'
    base = Claim.includes(:user).where.not(state: 'draft').where(fact: false)
    @claims = case @filter
              when 'approval_request'
                base.where(state: 'ai_validated')
              else
                base
              end.order(created_at: :desc)
    @claims = @claims.page(params[:page]).per(12)
    @top_facts = Claim.published_facts
                      .left_joins(:likes)
                      .group('claims.id')
                      .order(Arel.sql('COUNT(likes.id) DESC'))
                      .limit(2)
                      .includes(:user)
  end
end
