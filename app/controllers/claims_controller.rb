# frozen_string_literal: true

class ClaimsController < ApplicationController
  before_action :set_claim, only: %i[show edit update destroy]
  before_action :authenticate_user!
  layout 'dashboard'

  SOURCE_ENUM_MAP = {
    "Quran" => :quran,
    "Tanakh" => :tanakh,
    "Catholic" => :catholic,
    "Ethiopian" => :ethiopian,
    "Protestant" => :protestant,
    "Historical" => :historical
  }

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

  def validate_evidence
    evidence = params[:evidence]
    sources = params[:sources]

    result = LsvEvidenceValidatorService.new(evidence, sources).analyze_sources!

    render json: result
  rescue LsvEvidenceValidatorService::ValidationError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue StandardError => e
    Rails.logger.error "Evidence validation failed: #{e.message}"
    render json: { error: 'An unexpected error occurred during evidence validation.' }, status: :internal_server_error
  end

  def create
    if params[:claim][:content].blank?
      flash[:alert] = 'Claim content is required.'
      @claim = current_user.claims.new(claim_params)
      render :new, status: :unprocessable_entity
      return
    end

    evidences_param = params[:claim][:evidences]
    evidences = if evidences_param.is_a?(String)
      begin
        JSON.parse(evidences_param)
      rescue
        []
      end
    elsif evidences_param.is_a?(Array)
      evidences_param
    else
      []
    end
    # Treat each evidence as a plain string or a hash with evidence and source
    evidences = evidences.map do |ev|
      if ev.is_a?(String)
        { evidence: ev, source: nil }
      elsif ev.is_a?(Hash) && (ev[:evidence] || ev['evidence'])
        {
          evidence: ev[:evidence] || ev['evidence'],
          source: ev[:source] || ev['source']
        }
      else
        { evidence: ev.to_s, source: nil }
      end
    end

    if evidences.empty? || evidences.all? { |ev| ev[:evidence].blank? }
      flash[:alert] = 'At least one evidence is required.'
      @claim = current_user.claims.new(claim_params)
      render :new, status: :unprocessable_entity
      return
    end

    if params[:save_as_draft] == 'true'
      @claim = current_user.claims.new(claim_params.except(:evidences).merge(state: 'draft'))
      if @claim.save
        evidences.each do |evidence_hash|
          next if evidence_hash[:evidence].blank?
          source_enum = SOURCE_ENUM_MAP[evidence_hash[:source].to_s.strip] || :historical
          @claim.evidences.create!(
            content: evidence_hash[:evidence],
            source: source_enum
          )
        end
        redirect_to claims_path(filter: 'drafts'), notice: 'Claim saved as draft.'
      else
        render :new, status: :unprocessable_entity
      end
    else
      @claim = current_user.claims.new(claim_params.except(:evidences))
      if @claim.save
        evidences.each do |evidence_hash|
          next if evidence_hash[:evidence].blank?
          source_enum = SOURCE_ENUM_MAP[evidence_hash[:source].to_s.strip] || :historical
          @claim.evidences.create!(
            content: evidence_hash[:evidence],
            source: source_enum
          )
        end
        response = LsvValidatorService.new(@claim).run_validation!
        store_claim_result(@claim) if response
        redirect_to @claim, notice: "Claim validated successfully."
      else
        render :new, status: :unprocessable_entity
      end
    end
  end

  def show; end

  def edit; end

  def update
    if params[:claim][:content].blank?
      flash.now[:alert] = 'Claim content is required.'
      render :edit, status: :unprocessable_entity
      return
    end

    evidences_param = params[:claim][:evidences]
    evidences = if evidences_param.is_a?(String)
      begin
        JSON.parse(evidences_param)
      rescue
        []
      end
    elsif evidences_param.is_a?(Array)
      evidences_param
    else
      []
    end
    # Treat each evidence as a plain string or a hash with evidence and source
    evidences = evidences.map do |ev|
      if ev.is_a?(String)
        { evidence: ev, source: nil }
      elsif ev.is_a?(Hash) && (ev[:evidence] || ev['evidence'])
        {
          evidence: ev[:evidence] || ev['evidence'],
          source: ev[:source] || ev['source']
        }
      else
        { evidence: ev.to_s, source: nil }
      end
    end

    if evidences.empty? || evidences.all? { |ev| ev[:evidence].blank? }
      flash.now[:alert] = 'At least one evidence is required.'
      render :edit, status: :unprocessable_entity
      return
    end

    if params[:save_as_draft] == 'true'
      if @claim.update(claim_params.except(:evidences).merge(state: 'draft'))
        @claim.evidences.destroy_all
        evidences.each do |evidence_hash|
          next if evidence_hash[:evidence].blank?
          source_enum = SOURCE_ENUM_MAP[evidence_hash[:source].to_s.strip] || :historical
          @claim.evidences.create!(
            content: evidence_hash[:evidence],
            source: source_enum
          )
        end
        redirect_to claims_path(filter: 'drafts'), notice: 'Claim saved as draft.'
      else
        render :edit, status: :unprocessable_entity
      end
    else
      if @claim.update(claim_params.except(:evidences))
        @claim.evidences.destroy_all
        evidences.each do |evidence_hash|
          next if evidence_hash[:evidence].blank?
          source_enum = SOURCE_ENUM_MAP[evidence_hash[:source].to_s.strip] || :historical
          @claim.evidences.create!(
            content: evidence_hash[:evidence],
            source: source_enum
          )
        end
        response = LsvValidatorService.new(@claim).run_validation!
        store_claim_result(@claim) if response
        redirect_to @claim, notice: 'Claim updated and validated successfully.'
      else
        render :edit, status: :unprocessable_entity
      end
    end
  end

  def destroy
    @claim.destroy
    redirect_to claims_path(filter: 'drafts'), notice: 'Claim deleted successfully.'
  end

  def reasoning_for_source
    @claim = Claim.find(params[:id])
    @reasoning = @claim.reasonings.find_by(source: params[:source])
    if @reasoning
      render partial: 'reasonings/reasoning_response', locals: { reasoning: @reasoning }
    else
      head :not_found
    end
  end

  private

  def set_claim
    @claim = Claim.find(params[:id])
  end

  def store_claim_result(claim)
    primary_reasonings = claim.reasonings.where(primary_source: true)
    if primary_reasonings.any? { |r| r.result == '❌ False' }
      claim.update(result: '❌ False', state: 'ai_validated')
    elsif primary_reasonings.all? { |r| r.result == '✅ True' } && primary_reasonings.any?
      claim.update(result: '✅ True', state: 'ai_validated')
    end
  end

  def claim_params
    parsed_params = params.require(:claim).permit(:content, :primary_sources, :secondary_sources, :draft, :evidences)
    
    if parsed_params[:primary_sources].is_a?(String)
      parsed_params[:primary_sources] = JSON.parse(parsed_params[:primary_sources]) rescue []
    end

    if parsed_params[:secondary_sources].is_a?(String)
      parsed_params[:secondary_sources] = JSON.parse(parsed_params[:secondary_sources]) rescue []
    end
    
    parsed_params
  end
end
