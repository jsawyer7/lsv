class ClaimsController < ApplicationController
  before_action :authenticate_user!
  layout 'dashboard'

  def index
    filter = params[:filter] || 'all'
    @filter = filter
    @claims = case filter
    when 'drafts'
      current_user.claims.drafts
    when 'ai_validated'
      current_user.claims.ai_validated
    when 'verified'
      current_user.claims.verified
    else
      current_user.claims
    end.order(created_at: :desc)
    @claims = @claims.where('content ILIKE ?', "%#{params[:search]}%") if params[:search].present?
    @claims = @claims.page(params[:page]).per(12)
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
    if params[:claim][:content].blank? || params[:claim][:evidence].blank?
      flash[:alert] = 'Both claim and evidence are required.'
      @claim = Claim.new(claim_params)
      render :new, status: :unprocessable_entity
      return
    end

    if params[:save_as_draft] == 'true'
      @claim = current_user.claims.new(claim_params.merge(state: 'draft'))

      if @claim.save
        redirect_to claims_path(filter: 'drafts'), notice: 'Claim saved as draft.'
      else
        render :new, status: :unprocessable_entity
      end
    else
      @claim = current_user.claims.new(claim_params)

      if @claim.save
        response = LsvValidatorService.new(@claim).run_validation!
        store_claim_result(@claim) if response
        redirect_to @claim, notice: "Claim validated successfully."
      else
        render :new, status: :unprocessable_entity
      end
    end
  end

  def show
    @claim = Claim.find(params[:id])
  end

  def edit
    @claim = current_user.claims.find(params[:id])
  end

  def update
    if params[:claim][:content].blank? || params[:claim][:evidence].blank?
      flash.now[:alert] = 'Both claim and evidence are required.'
      @claim = current_user.claims.find(params[:id])
      render :edit, status: :unprocessable_entity
      return
    end
    @claim = current_user.claims.find(params[:id])
    if params[:save_as_draft] == 'true'
      if @claim.update(claim_params.merge(state: 'draft'))
        redirect_to claims_path(filter: 'drafts'), notice: 'Claim saved as draft.'
      else
        render :edit, status: :unprocessable_entity
      end
    else
      if @claim.update(claim_params)
        response = LsvValidatorService.new(@claim).run_validation!
        store_claim_result(@claim) if response
        redirect_to @claim, notice: 'Claim updated and validated successfully.'
      else
        render :edit, status: :unprocessable_entity
      end
    end
  end

  def destroy
    @claim = current_user.claims.find(params[:id])
    @claim.destroy
    redirect_to claims_path(filter: 'drafts'), notice: 'Claim deleted successfully.'
  end

  private

  def store_claim_result(claim)
    primary_reasonings = claim.reasonings.where(primary_source: true)
    if primary_reasonings.any? { |r| r.result == '❌ False' }
      claim.update(result: '❌ False', state: 'ai_validated')
    elsif primary_reasonings.all? { |r| r.result == '✅ True' } && primary_reasonings.any?
      claim.update(result: '✅ True', state: 'ai_validated')
    end
  end

  def claim_params
    params.require(:claim).permit(:content, :evidence)
  end
end
