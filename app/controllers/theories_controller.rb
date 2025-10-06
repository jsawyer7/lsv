class TheoriesController < ApplicationController
  before_action :authenticate_user!
  layout 'dashboard'

  def index
    status = params[:status] || 'public'
    search = params[:search]
    @filters = %w[public in_review draft]
    @current_status = status
    @theories = current_user.theories.where(status: status)
    @theories = @theories.where('title ILIKE ? OR description ILIKE ?', "%#{search}%", "%#{search}%") if search.present?
    @theories = @theories.order(created_at: :desc).limit(10)

    # Dynamic data for sidebar sections
    setup_sidebar_data
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
    theories = current_user.theories.where(status: status)
    theories = theories.where('title ILIKE ? OR description ILIKE ?', "%#{search}%", "%#{search}%") if search.present?
    theories = theories.order(created_at: :desc).offset(10 * page).limit(10)
    render json: {
      theories: theories.as_json(only: [:id, :title, :description, :status, :created_at]),
      has_more: theories.size == 10
    }
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
    @theories = Theory.where.not(status: 'draft').order(created_at: :desc).limit(20)

    # Dynamic data for sidebar sections
    setup_sidebar_data
    render :public_theories
  end

  def public_infinite
    page = params[:page].to_i > 0 ? params[:page].to_i : 1
    per_page = 20
    offset = (page - 1) * per_page
    theories = Theory.where.not(status: 'draft').order(created_at: :desc).offset(offset).limit(per_page)
    render json: {
      theories: theories.map { |theory| render_to_string(partial: 'theory_card', formats: [:html], locals: { theory: theory }) },
      next_page: theories.size == per_page ? page + 1 : nil
    }
  end

  private

  def theory_params
    params.require(:theory).permit(:title, :description)
  end

  def setup_sidebar_data
    # Who to Follow: Get users with most followers, excluding current user
    if user_signed_in?
      # Get users that current user is not already following
      following_ids = current_user.following.pluck(:id)
      following_ids << current_user.id

      @who_to_follow = User.where.not(id: following_ids)
                          .left_joins(:reverse_follows)
                          .group('users.id')
                          .order('COUNT(follows.id) DESC')
                          .limit(3)
    else
      # For non-logged in users, show users with most followers
      @who_to_follow = User.left_joins(:reverse_follows)
                          .group('users.id')
                          .order('COUNT(follows.id) DESC')
                          .limit(3)
    end

    # Top Picks: Get most recent published theories
    @top_picks = Theory.where.not(status: 'draft')
                      .includes(:user)
                      .order(created_at: :desc)
                      .limit(3)
  end
end
