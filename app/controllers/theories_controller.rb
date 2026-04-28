class TheoriesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_theory_creation_access!, only: [:new, :create]
  layout 'dashboard'

  def index
    @top_facts = Claim.published_facts
                      .left_joins(:likes)
                      .group('claims.id')
                      .order(Arel.sql('COUNT(likes.id) DESC'))
                      .limit(2)
                      .includes(:user)
    status = params[:status] || 'all'
    search = params[:search]
    @filters = %w[all public in_review draft]
    @current_status = status
    @theories = current_user.theories
    @theories = @theories.where(status: status) unless status == 'all'
    @theories = @theories.includes(:likes)
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
    page = params[:page].to_i > 0 ? params[:page].to_i : 1
    per_page = page == 1 ? 30 : 20
    offset = (page - 1) * per_page
    status = params[:status] || params[:filter] || 'public'
    search = params[:search]
    theories = current_user.theories
    case status
    when 'public'
      theories = theories.where.not(status: 'draft')
    when 'in_review', 'draft'
      theories = theories.where(status: status)
    end
    theories = theories.includes(:user, :likes)
    theories = theories.where('title ILIKE ? OR description ILIKE ?', "%#{search}%", "%#{search}%") if search.present?
    theories = theories.order(created_at: :desc).offset(offset).limit(per_page)
    render json: {
      theories: theories.map { |theory|
        { html: render_to_string(partial: 'shared/feed_card_theory', locals: { theory: theory }, formats: [:html]) }
      },
      has_more: theories.size == per_page
    }
  end

  def show
    @theory = Theory.find(params[:id])
    # Filter comments to only show those visible to current user (peer network only)
    @visible_comments = @theory.comments.visible_to(current_user).includes(:user, :likes)
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
    @top_facts = Claim.published_facts
                      .left_joins(:likes)
                      .group('claims.id')
                      .order(Arel.sql('COUNT(likes.id) DESC'))
                      .limit(2)
                      .includes(:user)
    render :public_theories
  end

  def public_infinite
    page = params[:page].to_i > 0 ? params[:page].to_i : 1
    per_page = page == 1 ? 30 : 20
    offset = (page - 1) * per_page
    theories = Theory.where.not(status: 'draft').includes(:user, :likes).order(created_at: :desc).offset(offset).limit(per_page)
    render json: {
      theories: theories.map { |theory| { html: render_to_string(partial: 'shared/feed_card_theory', locals: { theory: theory }, formats: [:html]) } },
      has_more: theories.size == per_page
    }
  end

  private

  def ensure_theory_creation_access!
    return if current_user.can_create_theories?

    respond_to do |format|
      format.html do
        redirect_to subscription_settings_path,
                    alert: 'Theory creation is available on Contributor plan. Please upgrade your plan.'
      end
      format.json do
        render json: { error: 'Theory creation is available on Contributor plan.' }, status: :forbidden
      end
    end
  end

  def theory_params
    params.require(:theory).permit(:title, :description)
  end
end
