class TheoriesController < ApplicationController
  before_action :authenticate_user!
  layout 'dashboard'

  def index
    status = params[:status] || 'public'
    search = params[:search]
    @filters = %w[public in_review draft]
    @current_status = status
    @theories = current_user.theories.where(status: status).includes(:likes, comments: [:user, :likes])
    @theories = @theories.where('title ILIKE ? OR description ILIKE ?', "%#{search}%", "%#{search}%") if search.present?
    @theories = @theories.order(created_at: :desc).limit(10)
  end

  def new
    @theory = current_user.theories.new
  end

  def create
    @theory = current_user.theories.new(theory_params)
    if params[:commit_draft]
      @theory.status = 'draft'
      notice = 'Theory saved as draft.'
    else
      @theory.status = 'in_review'
      notice = 'Theory submitted for review.'
    end

    if @theory.save
      redirect_to theories_path, notice: notice
    else
      render :new
    end
  end

  def infinite
    status = params[:status] || 'public'
    search = params[:search]
    page = params[:page].to_i
    theories = current_user.theories.where(status: status).includes(:likes, comments: [:user, :likes])
    theories = theories.where('title ILIKE ? OR description ILIKE ?', "%#{search}%", "%#{search}%") if search.present?
    theories = theories.order(created_at: :desc).offset(10 * page).limit(10)
    render json: {
      theories: theories.map { |theory|
        user_like = current_user ? theory.likes.find_by(user: current_user) : nil
        theory.as_json(only: [:id, :title, :description, :status, :created_at]).merge(
          likes_count: theory.likes.count,
          user_liked: user_like.present?,
          like_id: user_like&.id
        )
      },
      has_more: theories.size == 10
    }
  end

  def show
    @theory = Theory.includes(comments: [:user, :likes]).find(params[:id])
  end

  def edit
    @theory = current_user.theories.find(params[:id])
  end

  def update
    @theory = current_user.theories.find(params[:id])
    if params[:commit_draft]
      @theory.status = 'draft'
      notice = 'Theory saved as draft.'
    else
      @theory.status = 'in_review'
      notice = 'Theory submitted for review.'
    end
    if @theory.update(theory_params)
      redirect_to theories_path, notice: notice
    else
      render :edit
    end
  end

  def destroy
    @theory = current_user.theories.find(params[:id])
    @theory.destroy
    redirect_to theories_path, notice: 'Theory deleted.'
  end

  def public_theories
    @theories = Theory.where.not(status: 'draft').includes(:likes, comments: [:user, :likes]).order(created_at: :desc).limit(20)
    render :public_theories
  end

  def public_infinite
    page = params[:page].to_i > 0 ? params[:page].to_i : 1
    per_page = 20
    offset = (page - 1) * per_page
    theories = Theory.where.not(status: 'draft').includes(:likes, comments: [:user, :likes]).order(created_at: :desc).offset(offset).limit(per_page)
    render json: {
      theories: theories.map { |theory| render_to_string(partial: 'theory_card', formats: [:html], locals: { theory: theory }) },
      next_page: theories.size == per_page ? page + 1 : nil
    }
  end

  private

  def theory_params
    params.require(:theory).permit(:title, :description)
  end
end
