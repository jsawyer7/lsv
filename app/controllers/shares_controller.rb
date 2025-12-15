class SharesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_shareable, only: [:create]
  layout 'dashboard'

  def index
    # Show shared feed - items shared with current user
  end

  def reshare
    # Check if resharing from a share (shared feed) or directly from a shareable item
    if params[:id]
      # Resharing from a received share
      share = current_user.received_shares.find_by(id: params[:id])
      if share
        shareable = share.shareable
      else
        return head :not_found
      end
    elsif params[:claim_id]
      # Resharing directly from a claim
      shareable = Claim.find(params[:claim_id])
    elsif params[:theory_id]
      # Resharing directly from a theory
      shareable = Theory.find(params[:theory_id])
    elsif params[:comment_id]
      # Resharing directly from a comment
      if params[:claim_id]
        shareable = Claim.find(params[:claim_id]).comments.find(params[:comment_id])
      elsif params[:theory_id]
        shareable = Theory.find(params[:theory_id]).comments.find(params[:comment_id])
      else
        shareable = Comment.find(params[:comment_id])
      end
    else
      return head :bad_request
    end

    # Check if already reshared by this user
    existing_reshare = Share.find_by(user: current_user, shareable: shareable, recipient_id: nil)
    if existing_reshare
      respond_to do |format|
        format.html { redirect_to feeds_path, notice: 'You have already reshared this item.' }
        format.json { render json: { status: 'error', message: 'You have already reshared this item.' }, status: :unprocessable_entity }
      end
      return
    end

    # Create a reshare (public feed share) - recipient_id is nil for reshared items
    reshare = Share.new(
      user: current_user,
      shareable: shareable,
      recipient: nil, # nil means it's a public reshare
      message: params[:message]
    )

    authorize reshare

    if reshare.save
      respond_to do |format|
        format.html { redirect_to feeds_path, notice: 'Reshared to your feed!' }
        format.json { render json: { status: 'success', message: 'Reshared to your feed!' } }
      end
    else
      respond_to do |format|
        format.html { redirect_back(fallback_location: feeds_path, alert: reshare.errors.full_messages.first) }
        format.json { render json: { status: 'error', message: reshare.errors.full_messages.first }, status: :unprocessable_entity }
      end
    end
  end

  def infinite
    page = params[:page].to_i > 0 ? params[:page].to_i : 1
    per_page = 20

    # Get shares received by current user
    shares = current_user.received_shares
                        .includes(shareable: [:user, :likes], user: [])
                        .recent
                        .offset((page - 1) * per_page)
                        .limit(per_page)

    render json: {
      shares: shares.map { |share|
        shareable = share.shareable
        case shareable
        when Claim
          user_like = current_user ? shareable.likes.find_by(user: current_user) : nil
          {
            id: share.id,
            type: 'claim',
            shareable: {
              id: shareable.id,
              content: shareable.content_for_user(current_user),
              created_at: shareable.created_at,
              likes_count: shareable.likes.count,
              user_liked: user_like.present?,
              like_id: user_like&.id,
              user: {
                full_name: shareable.user&.full_name,
                email: shareable.user&.email
              }
            },
            shared_by: {
              full_name: share.user&.full_name,
              email: share.user&.email,
              avatar_url: share.user&.avatar_url
            },
            message: share.message,
            created_at: share.created_at,
            read_at: share.read_at
          }
        when Theory
          user_like = current_user ? shareable.likes.find_by(user: current_user) : nil
          {
            id: share.id,
            type: 'theory',
            shareable: {
              id: shareable.id,
              title: shareable.title,
              description: shareable.description,
              created_at: shareable.created_at,
              likes_count: shareable.likes.count,
              user_liked: user_like.present?,
              like_id: user_like&.id,
              user: {
                full_name: shareable.user&.full_name,
                email: shareable.user&.email
              }
            },
            shared_by: {
              full_name: share.user&.full_name,
              email: share.user&.email,
              avatar_url: share.user&.avatar_url
            },
            message: share.message,
            created_at: share.created_at,
            read_at: share.read_at
          }
        when Comment
          {
            id: share.id,
            type: 'comment',
            shareable: {
              id: shareable.id,
              content: shareable.content,
              created_at: shareable.created_at,
              user: {
                full_name: shareable.user&.full_name,
                email: shareable.user&.email
              }
            },
            shared_by: {
              full_name: share.user&.full_name,
              email: share.user&.email,
              avatar_url: share.user&.avatar_url
            },
            message: share.message,
            created_at: share.created_at,
            read_at: share.read_at
          }
        else
          nil
        end
      }.compact,
      has_more: shares.size == per_page
    }
  end

  def create
    recipient_ids = params[:recipient_ids] || []

    if recipient_ids.empty?
      respond_to do |format|
        format.html { redirect_back(fallback_location: root_path, alert: 'Please select at least one peer to share with.') }
        format.json { render json: { status: 'error', message: 'Please select at least one peer to share with.' }, status: :unprocessable_entity }
      end
      return
    end

    shares_created = []
    errors = []

    recipient_ids.each do |recipient_id|
      recipient = User.find_by(id: recipient_id)
      next unless recipient

      # Check if user is a peer with the recipient
      unless current_user.peers.include?(recipient) || current_user.peer_users.include?(recipient)
        errors << "You can only share with your peers."
        next
      end

      # Check if already shared with this recipient
      existing_share = @shareable.shares.find_by(user: current_user, recipient: recipient)
      if existing_share
        # Update existing share message if provided
        if params[:message].present?
          existing_share.update(message: params[:message])
        end
        shares_created << existing_share
        next
      end

      share = @shareable.shares.build(
        user: current_user,
        recipient: recipient,
        message: params[:message]
      )

      authorize share

      if share.save
        shares_created << share
      else
        errors << share.errors.full_messages.first
      end
    end

    if shares_created.any?
      respond_to do |format|
        format.html { redirect_back(fallback_location: root_path, notice: "Shared with #{shares_created.count} peer(s) successfully!") }
        format.json { render json: { status: 'success', message: "Shared with #{shares_created.count} peer(s)", shares_count: shares_created.count } }
      end
    else
      respond_to do |format|
        format.html { redirect_back(fallback_location: root_path, alert: errors.first || 'Unable to share. Please try again.') }
        format.json { render json: { status: 'error', message: errors.first || 'Unable to share. Please try again.' }, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_shareable
    if params[:claim_id]
      @shareable = Claim.find(params[:claim_id])
    elsif params[:theory_id]
      @shareable = Theory.find(params[:theory_id])
    elsif params[:comment_id]
      # Comments are nested under claims or theories
      if params[:claim_id]
        @shareable = Claim.find(params[:claim_id]).comments.find(params[:comment_id])
      elsif params[:theory_id]
        @shareable = Theory.find(params[:theory_id]).comments.find(params[:comment_id])
      else
        @shareable = Comment.find(params[:comment_id])
      end
    else
      head :bad_request
    end
  end
end
