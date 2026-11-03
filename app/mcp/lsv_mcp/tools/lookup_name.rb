module LsvMcp
  module Tools
    class LookupName < LsvMcp::Tool
      COLUMNS = %w[actual jewish christian muslim ethiopian].freeze

      requires_scope 'dictionary'
      tool_name 'lookup_name'
      description 'Look up how a name is written in each tradition (actual, Jewish, Christian, Muslim, Ethiopian), ' \
                  'e.g. Moses / Moshe / Musa. Case-insensitive substring match across all forms.'
      input_schema(
        properties: {
          name: { type: 'string', minLength: 2, maxLength: 100 },
          limit: { type: 'integer', minimum: 1, maximum: 50, default: 20 }
        },
        required: %w[name],
        additionalProperties: false
      )

      def run(name:, limit: nil)
        condition = COLUMNS.map { |c| "name_mappings.#{c} ILIKE :q" }.join(' OR ')
        mappings = NameMapping.where(condition, q: like_pattern(name))
                              .order(:internal_id).limit(clamp_limit(limit, default: 20, max: 50)).to_a
        {
          query: name,
          count: mappings.size,
          names: mappings.map { |m| { internal_id: m.internal_id }.merge(COLUMNS.to_h { |c| [c, m[c]] }) }
        }
      end
    end
  end
end
