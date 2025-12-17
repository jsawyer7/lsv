module Verifaith
  module PunctuationProfiles
    DEFAULT_PUNCT = /[·,.;:!?«»"ʼ'()\[\]{}]/.freeze

    BY_SOURCE_CODE = {
      'LXX_SWETE' => /[·,.;:!?«»"ʼ'()\[\]{}]/,
      'GRK_WH1881' => /[·,.;:!?«»"ʼ'()\[\]{}]/
    }.freeze

    module_function

    def regex_for(source)
      sc = SourceClassifier.new(source)
      BY_SOURCE_CODE[sc.code] || DEFAULT_PUNCT
    end

    # Normalize for token presence checks, NOT for canonical fidelity.
    # For Swete, treat middle dot as whitespace to preserve token boundaries.
    def normalize(text, source:)
      sc = SourceClassifier.new(source)
      s = text.to_s.downcase

      if sc.swete?
        # Treat middle dot as whitespace to preserve token boundaries
        s = s.gsub('·', ' ')
      end

      punct = regex_for(source)
      s = s.gsub(punct, ' ')
      s.gsub(/\s+/, ' ').strip
    end
  end
end



