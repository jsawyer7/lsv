class ChallengesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_claim, only: [:create]
  before_action :set_challenge, only: [:show]

  def create
    @challenge = @claim.challenges.build(challenge_params.merge(user: current_user))
    if @challenge.save
      LsvChallengeClaimService.new(@challenge).process
      respond_to do |format|
        format.html { redirect_to claim_path(@claim), notice: 'Challenge submitted successfully.' }
        format.json {
          render json: {
            status: :success,
            challenge: @challenge.as_json,
            html: render_to_string(partial: 'challenges/challenge', collection: @claim.challenges, formats: [:html])
          }, status: :created
        }
      end
    else
      respond_to do |format|
        format.html {
          flash[:alert] = 'Failed to submit challenge.'
          redirect_to claim_path(@claim)
        }
        format.json {
          render json: {
            status: :error,
            errors: @challenge.errors.full_messages
          }, status: :unprocessable_entity
        }
      end
    end
  end

  def create_for_evidence
    evidence = Evidence.find(params[:evidence_id])
    @challenge = evidence.challenges.build(
      challenge_params.merge(
        user: current_user,
        claim_id: evidence.claim_id
      )
    )
    if @challenge.save
      LsvChallengeEvidenceService.new(@challenge).process
      respond_to do |format|
        format.html { redirect_to claim_path(evidence.claim), notice: 'Evidence challenge submitted successfully.' }
        format.json {
          render json: {
            status: :success,
            challenge: @challenge.as_json,
            html: render_to_string(partial: 'challenges/challenge', collection: evidence.challenges.order(created_at: :desc), formats: [:html])
          }, status: :created
        }
      end
    else
      respond_to do |format|
        format.html {
          flash[:alert] = 'Failed to submit evidence challenge.'
          redirect_to claim_path(evidence.claim)
        }
        format.json {
          render json: {
            status: :error,
            errors: @challenge.errors.full_messages
          }, status: :unprocessable_entity
        }
      end
    end
  end

  def show
    respond_to do |format|
      format.html
      format.json { render json: @challenge }
    end
  end

  private

  def set_claim
    @claim = Claim.find(params[:claim_id])
  end

  def set_challenge
    @challenge = @claim.challenges.find(params[:id])
  end

  def challenge_params
    params.require(:challenge).permit(:text)
  end
end
