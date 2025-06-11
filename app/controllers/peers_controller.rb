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
      # Only exclude users with an accepted peer relationship
      accepted_peer_ids = Peer.where(user_id: current_user.id, status: 'accepted').pluck(:peer_id) +
                          Peer.where(peer_id: current_user.id, status: 'accepted').pluck(:user_id)
      @suggested_users = User.where.not(id: current_user.id)
                            .where.not(id: accepted_peer_ids)
                            .order('RANDOM()')
                            .page(params[:page]).per(8)
    end
    @my_peers = current_user.peers.limit(5)
    @my_peers_count = current_user.peers.count
    # Top facts can be static for now
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
