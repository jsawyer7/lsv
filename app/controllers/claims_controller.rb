# frozen_string_literal: true

class ClaimsController < ApplicationController
  before_action :set_claim, only: %i[show edit update destroy publish_fact unpublish_fact]
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

      # Check for duplicates
      detector = DuplicateClaimDetectorService.new(cleaned_claim)
      duplicates = detector.detect_duplicates

      render json: {
        valid: true,
        cleaned_claim: cleaned_claim,
        duplicates: duplicates
      }
    else
      render json: { valid: false, error: result[:reason] }, status: :unprocessable_entity
    end
  end

  # Remove validate_evidence endpoint - source validation is now handled on frontend
  def generate_ai_evidence
    claim_content = params[:claim_content]
    evidence_type = params[:evidence_type]
    user_query = params[:user_query]

    unless claim_content.present?
      render json: { error: 'Claim content is required' }, status: :bad_request
      return
    end

    begin
      case evidence_type
      when 'verse'
        service = AiVerseEvidenceService.new(claim_content)
        result = service.generate_verse_evidence(user_query)
      when 'historical'
        service = AiHistoricalEvidenceService.new(claim_content)
        result = service.generate_historical_evidence(user_query)
      when 'definition'
        service = AiDefinitionEvidenceService.new(claim_content)
        result = service.generate_definition_evidence(user_query)
      when 'logic'
        service = AiLogicEvidenceService.new(claim_content)
        result = service.generate_logic_evidence(user_query)
      else
        render json: { error: 'Invalid evidence type' }, status: :bad_request
        return
      end

      if result[:success]
        render json: { success: true, evidence: result }
      else
        render json: { success: false, error: result[:error] }, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error "AI Evidence generation failed: #{e.message}"
      render json: { success: false, error: 'Failed to generate evidence' }, status: :internal_server_error
    end
  end

  def create
    Rails.logger.info "Create action params: #{params.inspect}"

    if params[:claim][:content].blank?
      flash[:alert] = 'Claim content is required.'
      @claim = current_user.claims.new(claim_params)
      render :new, status: :unprocessable_entity
      return
    end

    # Parse evidence units from the combined field
    combined_evidence_field = params[:claim][:combined_evidence_field]
    Rails.logger.info "Combined evidence field: #{combined_evidence_field}"

    evidence_units = if combined_evidence_field.present?
      begin
        JSON.parse(combined_evidence_field)
      rescue JSON::ParserError
        []
      end
    else
      []
    end

    Rails.logger.info "Parsed evidence units: #{evidence_units.inspect}"

    if evidence_units.empty?
      flash[:alert] = 'At least one evidence is required.'
      @claim = current_user.claims.new(claim_params)
      render :new, status: :unprocessable_entity
      return
    end

    if params[:save_as_draft] == 'true'
      @claim = current_user.claims.new(claim_params.except(:combined_evidence_field).merge(state: 'draft'))
      if @claim.save
        create_evidence_from_units(@claim, evidence_units)
        redirect_to claims_path(filter: 'drafts'), notice: 'Claim saved as draft.'
      else
        render :new, status: :unprocessable_entity
      end
    else
      @claim = current_user.claims.new(claim_params.except(:combined_evidence_field))
      if @claim.save
        create_evidence_from_units(@claim, evidence_units)
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

    # Parse evidence units from the combined field
    combined_evidence_field = params[:claim][:combined_evidence_field]
    evidence_units = if combined_evidence_field.present?
      begin
        JSON.parse(combined_evidence_field)
      rescue JSON::ParserError
        []
      end
    else
      []
    end

    if evidence_units.empty?
      flash.now[:alert] = 'At least one evidence is required.'
      render :edit, status: :unprocessable_entity
      return
    end

    if params[:save_as_draft] == 'true'
      if @claim.update(claim_params.except(:combined_evidence_field).merge(state: 'draft'))
        @claim.evidences.destroy_all
        create_evidence_from_units(@claim, evidence_units)
        redirect_to claims_path(filter: 'drafts'), notice: 'Claim saved as draft.'
      else
        render :edit, status: :unprocessable_entity
      end
    else
      if @claim.update(claim_params.except(:combined_evidence_field))
        @claim.evidences.destroy_all
        create_evidence_from_units(@claim, evidence_units)
        response = LsvValidatorService.new(@claim).run_validation!
        store_claim_result(@claim) if response
        redirect_to @claim, notice: "Claim updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end
  end

  def destroy
    @claim.destroy
    redirect_to claims_path, notice: 'Claim was successfully deleted.'
  end

  def publish_fact
    if @claim.fact?
      @claim.update(published: true)

      # Generate embedding for the published fact
      begin
        embedding_service = ClaimEmbeddingService.new(@claim.content)
        embedding = embedding_service.generate_embedding
        normalized_hash = embedding_service.generate_hash

        if embedding.present? && normalized_hash.present?
          @claim.update_columns(
            content_embedding: embedding,
            normalized_content_hash: normalized_hash
          )
          Rails.logger.info "Generated embedding for published fact #{@claim.id}"
        else
          Rails.logger.error "Failed to generate embedding for published fact #{@claim.id}"
        end
      rescue => e
        Rails.logger.error "Error generating embedding for published fact #{@claim.id}: #{e.message}"
      end

      respond_to do |format|
        format.html { redirect_to @claim, notice: 'Fact published successfully!' }
        format.json { render json: { status: 'success', message: 'Fact published successfully!' } }
      end
    else
      respond_to do |format|
        format.html { redirect_to @claim, alert: 'Only facts can be published.' }
        format.json { render json: { status: 'error', message: 'Only facts can be published.' }, status: :unprocessable_entity }
      end
    end
  end

  def unpublish_fact
    if @claim.fact?
      @claim.update(published: false)

    # Remove embeddings when fact is unpublished
    @claim.update_columns(content_embedding: nil, normalized_content_hash: nil)

    respond_to do |format|
        format.html { redirect_to @claim, notice: 'Fact unpublished successfully!' }
        format.json { render json: { status: 'success', message: 'Fact unpublished successfully!' } }
      end
    else
      respond_to do |format|
        format.html { redirect_to @claim, alert: 'Only facts can be unpublished.' }
        format.json { render json: { status: 'error', message: 'Only facts can be unpublished.' }, status: :unprocessable_entity }
      end
    end
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
    parsed_params = params.require(:claim).permit(:content, :primary_sources, :secondary_sources, :draft, :combined_evidence_field)

    # Parse primary_sources and secondary_sources from JSON strings to arrays
    if parsed_params[:primary_sources].present?
      begin
        parsed_params[:primary_sources] = JSON.parse(parsed_params[:primary_sources])
      rescue JSON::ParserError
        parsed_params[:primary_sources] = []
      end
    else
      parsed_params[:primary_sources] = []
    end

    if parsed_params[:secondary_sources].present?
      begin
        parsed_params[:secondary_sources] = JSON.parse(parsed_params[:secondary_sources])
      rescue JSON::ParserError
        parsed_params[:secondary_sources] = []
      end
    else
      parsed_params[:secondary_sources] = []
    end

    parsed_params
  end

  # New method to create evidence from evidence units
  def create_evidence_from_units(claim, evidence_units)
    evidence_units.each do |unit|
      next unless unit['sections'] && unit['sections'].any?
      # Create evidence
      evidence = claim.evidences.create!
      # Store all sections as JSON in content
      evidence.set_evidence_sections(unit['sections'])
      # Save the evidence to persist the content
      evidence.save!
      # Extract and populate individual fields from the sections
      evidence.populate_structured_fields
      evidence.save!
    end
  end
end
