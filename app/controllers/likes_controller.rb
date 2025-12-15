class LikesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_likeable

  def create
    @like = current_user.likes.build(likeable: @likeable)

    authorize @like

    if @like.save
      respond_to do |format|
        format.html { redirect_back(fallback_location: root_path, notice: 'Liked successfully!') }
        format.json { render json: { status: 'success', likes_count: @likeable.likes.count, like_id: @like.id } }
      end
    else
      respond_to do |format|
        format.html { redirect_back(fallback_location: root_path, alert: @like.errors.full_messages.first) }
        format.json { render json: { status: 'error', message: @like.errors.full_messages.first }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @like = current_user.likes.find_by(likeable: @likeable)

    if @like
      authorize @like
      @like.destroy

      respond_to do |format|
        format.html { redirect_back(fallback_location: root_path, notice: 'Unliked successfully!') }
        format.json { render json: { status: 'success', likes_count: @likeable.likes.count, liked: false } }
      end
    else
      respond_to do |format|
        format.html { redirect_back(fallback_location: root_path, alert: 'Like not found') }
        format.json { render json: { status: 'error', message: 'Like not found' }, status: :not_found }
      end
    end
  end

  private

  def set_likeable
    if params[:comment_id]
      # Comment likes are nested under claims or theories
      if params[:claim_id]
        @likeable = Claim.find(params[:claim_id]).comments.find(params[:comment_id])
      elsif params[:theory_id]
        @likeable = Theory.find(params[:theory_id]).comments.find(params[:comment_id])
      else
        @likeable = Comment.find(params[:comment_id])
      end
    elsif params[:claim_id]
      @likeable = Claim.find(params[:claim_id])
    elsif params[:theory_id]
      @likeable = Theory.find(params[:theory_id])
    else
      head :bad_request
    end
  end
end
