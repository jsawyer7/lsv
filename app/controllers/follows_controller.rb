class FollowsController < ApplicationController
  before_action :authenticate_user!

  def create
    followed_user = User.find(params[:followed_user_id])
    unless current_user.following.exists?(followed_user.id)
      current_user.follows.create(followed_user: followed_user)
    end
    respond_to do |format|
      format.html { redirect_back fallback_location: peers_path, notice: 'Followed successfully.' }
      format.js
    end
  end

  def destroy
    follow = current_user.follows.find_by(followed_user: params[:id])
    follow&.destroy
    respond_to do |format|
      format.html { redirect_back fallback_location: peers_path, notice: 'Unfollowed successfully.' }
      format.js
    end
  end
end
