module Verifaith
  class SourceClassifier
    def initialize(source)
      @source = source
    end

    def code
      if @source.respond_to?(:code)
        @source.code.to_s
      else
        @source.to_s
      end
    end

    def name
      if @source.respond_to?(:name)
        @source.name.to_s
      else
        @source.to_s
      end
    end

    def swete?
      c = code
      n = name
      c == 'LXX_SWETE' || c.include?('SWETE') || n.include?('Swete')
    end

    def lxx?
      c = code
      n = name
      swete? || c.include?('LXX') || n.include?('Septuagint')
    end

    def wh1881?
      c = code
      n = name
      c == 'GRK_WH1881' || c.include?('WH1881') || n.include?('Westcott') || n.include?('Hort')
    end

    def greek?
      lang_code =
        if @source.respond_to?(:language) && @source.language.respond_to?(:code)
          @source.language.code.to_s.downcase
        else
          ''
        end

      return true if %w[grc el greek].include?(lang_code)

      # Fallback: edition implies Greek
      lxx? || wh1881?
    end
  end
end



