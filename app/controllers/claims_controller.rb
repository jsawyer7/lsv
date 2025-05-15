class ClaimsController < ApplicationController
  before_action :authenticate_user!
  layout 'dashboard'

  def index
    @claims = current_user.claims.order(created_at: :desc).page(params[:page]).per(12)
    @claims = @claims.where('content ILIKE ?', "%#{params[:search]}%") if params[:search].present?
  end

  def new
    @claim = Claim.new
  end

  def create
    @claim = current_user.claims.new(claim_params)

    if @claim.save
      LsvValidatorService.new(@claim).run_validation!

      redirect_to @claim, notice: "Claim validated successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @claim = current_user.claims.find(params[:id])
  end

  private

  def claim_params
    params.require(:claim).permit(:content, :evidence)
  end
end
