class DashboardController < ApplicationController
  before_action :authenticate_user!
  def index
    @claims = current_user.claims.order(created_at: :desc)
  end
end
