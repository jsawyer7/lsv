class ChallengesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_challenge_access!, only: [:create, :create_for_evidence]
  before_action :set_claim, only: [:create, :destroy]
  before_action :set_challenge, only: [:show, :destroy]
  before_action :authorize_challenge_owner!, only: [:destroy]

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
            html: render_to_string(partial: 'challenges/challenge', collection: @claim.challenges.order(created_at: :desc), formats: [:html])
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
          claim = evidence.claim
          all_challenges = claim.challenges.where.not(evidence_id: nil).order(created_at: :desc)
          render json: {
            status: :success,
            challenge: @challenge.as_json,
            html: render_to_string(partial: 'challenges/challenge', collection: all_challenges, formats: [:html])
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

  def destroy
    @challenge.destroy
    respond_to do |format|
      format.html { redirect_to claim_path(@claim), notice: 'Challenge was deleted.' }
      format.json {
        all_challenges = @claim.challenges.where.not(evidence_id: nil).order(created_at: :desc)
        render json: {
          status: :success,
          html: render_to_string(partial: 'challenges/challenge', collection: all_challenges, formats: [:html])
        }
      }
    end
  end

  private

  def ensure_challenge_access!
    return if current_user.can_submit_challenges?

    respond_to do |format|
      format.html do
        flash[:timeout_ms] = 12000
        redirect_to subscription_settings_path,
                    alert: 'Ability to submit challenges is available on the Contributor plan only. Your current plan can read and discuss evidence, but to submit a challenge please upgrade your plan.'
      end
      format.json do
        render json: { error: 'Challenges are available on Contributor plan.' }, status: :forbidden
      end
    end
  end

  def set_claim
    @claim = Claim.find(params[:claim_id])
  end

  def set_challenge
    @challenge = @claim.challenges.find(params[:id])
  end

  def authorize_challenge_owner!
    return if @challenge.user_id == current_user.id
    respond_to do |format|
      format.html { redirect_to claim_path(@claim), alert: 'You can only delete your own challenge.' }
      format.json { render json: { status: :error, errors: ['You can only delete your own challenge.'] }, status: :forbidden }
    end
  end

  def challenge_params
    params.require(:challenge).permit(:text)
  end
end
