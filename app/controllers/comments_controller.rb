class CommentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_commentable

  def create
    @comment = @commentable.comments.build(comment_params)
    @comment.user = current_user

    authorize @comment

    if @comment.save
      respond_to do |format|
        format.html { redirect_back(fallback_location: root_path, notice: 'Comment added successfully!') }
        format.json { render json: { status: 'success', comment: render_comment(@comment) } }
      end
    else
      respond_to do |format|
        format.html { redirect_back(fallback_location: root_path, alert: @comment.errors.full_messages.first) }
        format.json { render json: { status: 'error', message: @comment.errors.full_messages.first }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @comment = @commentable.comments.find(params[:id])

    authorize @comment

    if @comment.destroy
      respond_to do |format|
        format.html { redirect_back(fallback_location: root_path, notice: 'Comment deleted successfully!') }
        format.json { render json: { status: 'success', message: 'Comment deleted' } }
      end
    else
      respond_to do |format|
        format.html { redirect_back(fallback_location: root_path, alert: 'Unable to delete comment') }
        format.json { render json: { status: 'error', message: 'Unable to delete comment' }, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_commentable
    if params[:claim_id]
      @commentable = Claim.find(params[:claim_id])
    elsif params[:theory_id]
      @commentable = Theory.find(params[:theory_id])
    else
      head :bad_request
    end
  end

  def comment_params
    params.require(:comment).permit(:content)
  end

  def render_comment(comment)
    ApplicationController.render(
      partial: 'comments/comment',
      locals: { comment: comment, current_user: current_user }
    )
  end
end
