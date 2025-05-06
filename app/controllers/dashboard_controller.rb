class DashboardController < ApplicationController
  before_action :authenticate_user!
  layout 'dashboard'

  def index
    @claims = current_user.claims.order(created_at: :desc).page(params[:page]).per(12)
    @claims = @claims.where('content ILIKE ?', "%#{params[:search]}%") if params[:search].present?
  end
end
