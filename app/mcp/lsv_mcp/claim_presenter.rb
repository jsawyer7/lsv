module LsvMcp
  # JSON shapes for claims, evidence, challenges and reasonings returned to Grok Bot.
  # Users are identified by id only; no names or emails leave LSV.
  module ClaimPresenter
    EVIDENCE_FIELDS = %w[content verse_reference original_text translation explanation historical_event description
                         relevance term definition etymology usage_context premise reasoning conclusion logical_form].freeze

    module_function

    def claim(claim)
      {
        id: claim.id,
        user_id: claim.user_id,
        content: claim.content,
        state: claim.state,
        fact: claim.fact,
        published: claim.published,
        result: claim.result,
        reasoning: claim.reasoning,
        primary_sources: claim.primary_sources,
        secondary_sources: claim.secondary_sources,
        created_at: claim.created_at.iso8601,
        updated_at: claim.updated_at.iso8601
      }
    end

    def evidence(evidence)
      fields = EVIDENCE_FIELDS.to_h { |f| [f, evidence[f]] }.compact_blank
      { id: evidence.id, claim_id: evidence.claim_id, sources: evidence.source_names }
        .merge(fields)
        .merge(created_at: evidence.created_at.iso8601)
    end

    def reasoning(reasoning)
      { source: reasoning.source, result: reasoning.result, primary_source: reasoning.primary_source,
        response: reasoning.response, created_at: reasoning.created_at.iso8601 }
    end

    def challenge(challenge)
      { id: challenge.id, user_id: challenge.user_id, claim_id: challenge.claim_id, evidence_id: challenge.evidence_id,
        text: challenge.text, status: challenge.status, created_at: challenge.created_at.iso8601 }
    end
  end
end
