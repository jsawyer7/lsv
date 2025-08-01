class PlansController < ApplicationController
  before_action :authenticate_user!
  
  def index
    @plans = Plan.active.by_price
  end
  
  def show
    @plan = Plan.find(params[:id])
    @current_subscription = current_user.current_subscription
  end
end
