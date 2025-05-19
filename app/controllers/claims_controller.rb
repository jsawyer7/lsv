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

  def validate_claim
    result = LsvInitialClaimValidatorService.new(params[:claim][:content]).run_validation!
    
    if result[:valid]
      cleaned_claim = result[:reason].presence || params[:claim][:content]
      render json: { valid: true, cleaned_claim: cleaned_claim }
    else
      render json: { valid: false, error: result[:reason] }, status: :unprocessable_entity
    end
  end

  def create
    @claim = current_user.claims.new(claim_params)

    if @claim.save
      response = LsvValidatorService.new(@claim).run_validation!
      store_claim_result(@claim) if response
      redirect_to @claim, notice: "Claim validated successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @claim = current_user.claims.find(params[:id])
  end

  private

  def store_claim_result(claim)
    primary_reasonings = claim.reasonings.where(primary_source: true)
    if primary_reasonings.any? { |r| r.result == '❌ False' }
      claim.update(result: '❌ False')
    elsif primary_reasonings.all? { |r| r.result == '✅ True' } && primary_reasonings.any?
      claim.update(result: '✅ True')
    end
  end

  def claim_params
    params.require(:claim).permit(:content, :evidence)
  end
end
