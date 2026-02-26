class PeersController < ApplicationController
  before_action :authenticate_user!
  layout 'dashboard'

  def index
    @tab = params[:tab] || 'suggestions'
    case @tab
    when 'requests'
      @requests = current_user.received_peer_requests.includes(:user).page(params[:page]).per(8)
    when 'following'
      @following = current_user.following.page(params[:page]).per(8)
    else
      # Use recommendation service for intelligent peer suggestions
      recommendation_service = PeerRecommendationService.new(current_user)
      recommendations = recommendation_service.recommendations(limit: 50)

      # Extract users from recommendations
      recommended_users = recommendations.map { |r| r[:user] }
      @recommendation_reasons = recommendations.index_by { |r| r[:user].id }

      # Paginate the recommendations
      @suggested_users = Kaminari.paginate_array(recommended_users).page(params[:page]).per(8)
    end
    @my_peers = current_user.peers.includes(:followers).limit(5)
    @my_peers_count = current_user.peers.count
    need_static = [3 - @my_peers.size, 0].max
    @my_peers_display = @my_peers.to_a + StaticPeer.take(need_static)
    @top_facts = Claim.published_facts
                      .left_joins(:likes)
                      .group('claims.id')
                      .order(Arel.sql('COUNT(likes.id) DESC'))
                      .limit(2)
                      .includes(:user)
  end

  def add
    peer = User.find(params[:peer_id])
    unless Peer.exists?(user_id: current_user.id, peer_id: peer.id)
      Peer.create(user: current_user, peer: peer, status: 'pending')
    end
    unless current_user.following.exists?(peer.id)
      Follow.create(user_id: current_user.id, followed_user: peer)
    end
    respond_to do |format|
      format.html { redirect_to peers_path(tab: 'suggestions'), notice: 'Peer request sent.' }
      format.js
    end
  end

  def accept
    peer_request = Peer.find_by(user_id: params[:user_id], peer_id: current_user.id, status: 'pending')
    if peer_request
      peer_request.update(status: 'accepted')
      unless Peer.exists?(user_id: current_user.id, peer_id: params[:user_id], status: 'accepted')
        Peer.create(user_id: current_user.id, peer_id: params[:user_id], status: 'accepted')
      end
    end
    respond_to do |format|
      format.html { redirect_to peers_path(tab: 'requests'), notice: 'Peer request accepted.' }
      format.js
    end
  end

  def remove
    peer = User.find(params[:peer_id])
    Peer.where(user_id: current_user.id, peer_id: peer.id).or(Peer.where(user_id: peer.id, peer_id: current_user.id)).destroy_all
    respond_to do |format|
      format.html { redirect_to peers_path(tab: 'following'), notice: 'Peer removed.' }
      format.js
    end
  end
end
