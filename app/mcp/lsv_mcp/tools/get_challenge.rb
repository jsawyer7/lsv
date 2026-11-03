module LsvMcp
  module Tools
    class GetChallenge < LsvMcp::Tool
      requires_scope 'claims'
      tool_name 'get_challenge'
      description 'Get one challenge: the user\'s challenge text, the claim and (if any) the evidence it challenges, ' \
                  'and the reasonings already recorded for the challenge.'
      input_schema(
        properties: { challenge_id: { type: 'integer', minimum: 1 } },
        required: %w[challenge_id],
        additionalProperties: false
      )

      def run(challenge_id:)
        challenge = Challenge.find_by(id: challenge_id) || raise(Error, "Challenge #{challenge_id} not found.")
        claim = Claim.find_by(id: challenge.claim_id)
        evidence = Evidence.find_by(id: challenge.evidence_id)

        {
          challenge: ClaimPresenter.challenge(challenge),
          claim: claim && ClaimPresenter.claim(claim),
          evidence: evidence && ClaimPresenter.evidence(evidence),
          reasonings: challenge.reasonings.order(:source).map { |r| ClaimPresenter.reasoning(r) },
          count: 1
        }
      end
    end
  end
end
