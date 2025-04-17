class ClaimsController < ApplicationController
  before_action :authenticate_user!

  def index
    @claims = current_user.claims.order(created_at: :desc)
  end

  def new
    @claim = Claim.new
  end

  def create
    @claim = current_user.claims.new(claim_params)

    if @claim.save
      response = LsvValidatorService.new(@claim).run_validation!
      @claim.update(result: response[:badge], reasoning: response[:reasoning])
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
