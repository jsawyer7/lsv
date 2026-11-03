module LsvMcp
  module Tools
    class SearchClaims < LsvMcp::Tool
      requires_scope 'claims'
      tool_name 'search_claims'
      description 'Search claims made in LSV by their text (case-insensitive substring), newest first. ' \
                  'Includes unpublished and draft claims. Use get_claim for the full claim with evidence and reasonings.'
      input_schema(
        properties: {
          text: { type: 'string', minLength: 2, maxLength: 200 },
          facts_only: { type: 'boolean', default: false, description: 'Only claims marked as facts.' },
          limit: { type: 'integer', minimum: 1, maximum: 50, default: 20 }
        },
        required: %w[text],
        additionalProperties: false
      )

      def run(text:, facts_only: false, limit: nil)
        scope = Claim.where('claims.content ILIKE ?', like_pattern(text))
        scope = scope.where(fact: true) if facts_only
        claims = scope.order(created_at: :desc, id: :desc).limit(clamp_limit(limit, default: 20, max: 50))
                      .select(:id, :content, :state, :fact, :published, :result, :created_at).to_a
        {
          query: text,
          count: claims.size,
          claims: claims.map do |c|
            { id: c.id, content: clip(c.content, 1_000), state: c.state, fact: c.fact, published: c.published,
              result: c.result, created_at: c.created_at.iso8601 }
          end
        }
      end
    end
  end
end
