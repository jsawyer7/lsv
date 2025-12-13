class FactsController < ApplicationController
  layout 'dashboard'

  def index
    @filters = %w[all my_facts]
    @current_filter = params[:filter] || 'all'
    @search = params[:search]
    @facts = Claim.published_facts.includes(:user, :likes, comments: [:user, :likes])
    @facts = @facts.where('content ILIKE ?', "%#{@search}%") if @search.present?
    @facts = @facts.order(created_at: :desc).limit(10)
  end

  def infinite
    page = params[:page].to_i
    search = params[:search]
    facts = Claim.where.not(state: 'draft').includes(:user, :likes, comments: [:user, :likes])
    facts = facts.where('content ILIKE ?', "%#{search}%") if search.present?
    facts = facts.order(created_at: :desc).offset(10 * page).limit(10)
    render json: {
      facts: facts.map { |fact| render_to_string(partial: 'fact_card', formats: [:html], locals: { fact: fact }) },
      has_more: facts.size == 10
    }
  end
end
