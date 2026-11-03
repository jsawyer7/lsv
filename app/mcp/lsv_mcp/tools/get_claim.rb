module LsvMcp
  module Tools
    class GetClaim < LsvMcp::Tool
      requires_scope 'claims'
      tool_name 'get_claim'
      description 'Get one claim with all its evidence, the per-tradition reasonings LSV produced for it ' \
                  '(Quran, Tanakh, Catholic, Ethiopian, Protestant, Historical) and the challenges raised against it.'
      input_schema(
        properties: { claim_id: { type: 'integer', minimum: 1 } },
        required: %w[claim_id],
        additionalProperties: false
      )

      def run(claim_id:)
        claim = Claim.find_by(id: claim_id) || raise(Error, "Claim #{claim_id} not found.")
        evidences = claim.evidences.order(:id).to_a
        challenges = Challenge.where(claim_id: claim.id).order(:id).to_a

        {
          claim: ClaimPresenter.claim(claim),
          reasonings: claim.reasonings.order(:source).map { |r| ClaimPresenter.reasoning(r) },
          evidences: evidences.map { |e| ClaimPresenter.evidence(e) },
          challenges: challenges.map { |c| ClaimPresenter.challenge(c) },
          count: 1
        }
      end
    end
  end
end
