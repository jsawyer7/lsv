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
    # Treat each evidence as a plain string or a hash with evidence and sources
    evidences = evidences.map do |ev|
      if ev.is_a?(String)
        { evidence: ev, sources: ['historical'] }
      elsif ev.is_a?(Hash) && (ev[:evidence] || ev['evidence'])
        {
          evidence: ev[:evidence] || ev['evidence'],
          sources: ev[:sources] || ev['sources'] || ev[:source] || ev['source'] || ['historical']
        }
      else
        { evidence: ev.to_s, sources: ['historical'] }
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

          # Handle multiple sources
          sources = Array(evidence_hash[:sources]).compact
          sources = ['historical'] if sources.empty?

          evidence = @claim.evidences.create!(content: evidence_hash[:evidence])

          # Add all sources to the evidence
          sources.each do |source_name|
            source_enum = SOURCE_ENUM_MAP[source_name.to_s.strip]
            evidence.add_source(source_enum) if source_enum
          end
          evidence.save!
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

          # Handle multiple sources
          sources = Array(evidence_hash[:sources]).compact
          sources = ['historical'] if sources.empty?

          evidence = @claim.evidences.create!(content: evidence_hash[:evidence])

          # Add all sources to the evidence
          sources.each do |source_name|
            source_enum = SOURCE_ENUM_MAP[source_name.to_s.strip]
            evidence.add_source(source_enum) if source_enum
          end
          evidence.save!
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
    # Treat each evidence as a plain string or a hash with evidence and sources
    evidences = evidences.map do |ev|
      if ev.is_a?(String)
        { evidence: ev, sources: ['historical'] }
      elsif ev.is_a?(Hash) && (ev[:evidence] || ev['evidence'])
        {
          evidence: ev[:evidence] || ev['evidence'],
          sources: ev[:sources] || ev['sources'] || ev[:source] || ev['source'] || ['historical']
        }
      else
        { evidence: ev.to_s, sources: ['historical'] }
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

          # Handle multiple sources
          sources = Array(evidence_hash[:sources]).compact
          sources = ['historical'] if sources.empty?

          evidence = @claim.evidences.create!(content: evidence_hash[:evidence])

          # Add all sources to the evidence
          sources.each do |source_name|
            source_enum = SOURCE_ENUM_MAP[source_name.to_s.strip]
            evidence.add_source(source_enum) if source_enum
          end
          evidence.save!
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

          # Handle multiple sources
          sources = Array(evidence_hash[:sources]).compact
          sources = ['historical'] if sources.empty?

          evidence = @claim.evidences.create!(content: evidence_hash[:evidence])

          # Add all sources to the evidence
          sources.each do |source_name|
            source_enum = SOURCE_ENUM_MAP[source_name.to_s.strip]
            evidence.add_source(source_enum) if source_enum
          end
          evidence.save!
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
    redirect_to claims_path, notice: 'Claim was successfully deleted.'
  end

  def publish_fact
    if @claim.fact?
      @claim.update(published: true)
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
