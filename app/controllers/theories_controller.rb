class TheoriesController < ApplicationController
  before_action :authenticate_user!
  layout 'dashboard'

  def index
    status = params[:status] || 'public'
    search = params[:search]
    @filters = %w[public in_review draft]
    @current_status = status
    @theories = Theory.where(status: status)
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
    theories = Theory.where(status: status)
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

  private

  def theory_params
    params.require(:theory).permit(:title, :description)
  end
end 