class AiVerseEvidenceService
  AVAILABLE_SOURCES = ['Quran', 'Tanakh', 'Catholic', 'Ethiopian', 'Protestant', 'Historical']

  def initialize(claim_content)
    @claim_content = claim_content
  end

  def generate_verse_evidence(user_query = nil)
    prompt = build_prompt(user_query)

    Rails.logger.info "AI Verse Evidence Service - User Query: #{user_query}"
    Rails.logger.info "AI Verse Evidence Service - Generated Prompt: #{prompt}"

    begin
      response = openai_client.chat(
        parameters: {
          model: "gpt-4o",
          messages: [
            {
              role: "system",
              content: "You are an expert in religious texts and translations. Focus on providing accurate, literal translations from source languages (Arabic, Hebrew, Greek, etc.) with proper context. You must identify ALL relevant sources for the verse from the available sources: #{AVAILABLE_SOURCES.join(', ')}. A single verse may be referenced in multiple sources."
            },
            {
              role: "user",
              content: prompt
            }
          ],
          temperature: 0.3,
          max_tokens: 1000
        }
      )

      Rails.logger.info "AI Verse Evidence Service - AI Response: #{response.dig("choices", 0, "message", "content")}"
      parse_response(response.dig("choices", 0, "message", "content"))
    rescue => e
      Rails.logger.error "AI Verse Evidence Service error: #{e.message}"
      { error: "Failed to generate verse evidence: #{e.message}" }
    end
  end

  private

  def build_prompt(user_query)
    base_prompt = <<~PROMPT
      For the claim: "#{@claim_content}"

      **CRITICAL USER REQUEST**: #{user_query ? user_query : "Please provide a relevant verse for this claim."}

      Please provide verse evidence with the following structure:

      1. **Verse Reference**: Include the exact verse name and number (e.g., "Quran 2:219", "Bible John 3:16", "Torah Genesis 1:1")
      2. **Original Text**: The text in its original language (Arabic, Hebrew, Greek, etc.)
      3. **Translation**: A direct, literal translation to English that maintains the original meaning
      4. **Explanation**: Brief explanation of the translation choices and context
      5. **Sources**: Identify ALL relevant sources from these available options: #{AVAILABLE_SOURCES.join(', ')}

      Important guidelines:
      - **CRITICAL**: You MUST use the specific verse requested by the user: "#{user_query}"
      - **CRITICAL**: Do NOT use any default or example verses - only the verse specifically requested
      - Focus on literal, direct translation rather than interpretive translation
      - Include context from surrounding verses if needed for accurate translation
      - **CRITICAL**: You must identify ALL relevant sources for the verse:
        * Quran verses (e.g., "Quran 2:219") → Sources: ["Quran"]
        * Torah/Old Testament verses (e.g., "Genesis 1:1", "Exodus 20:1") → Sources: ["Tanakh"]
        * New Testament verses (e.g., "John 3:16", "Matthew 5:1") → Sources: ["Catholic", "Protestant"] (if applicable to both)
        * Ethiopian Orthodox verses → Sources: ["Ethiopian"]
        * Protestant Bible verses → Sources: ["Protestant"]
        * Historical religious texts → Sources: ["Historical"]
        * Verses that appear in multiple sources (e.g., shared between Catholic and Protestant Bibles) → Sources: ["Catholic", "Protestant"]
      - A single verse may be referenced in multiple sources (e.g., a verse that appears in both Catholic and Protestant Bibles)
      - Ensure the verse directly supports or relates to the claim
      - Provide accurate transliteration of the original text

      Please format your response as JSON:
      {
        "verse_reference": "#{user_query}",
        "original_text": "Original text here",
        "translation": "English translation here",
        "explanation": "Explanation of translation choices and context",
        "sources": ["Quran"]
      }
    PROMPT

    base_prompt
  end

  def parse_response(content)
    begin
      # Try to extract JSON from the response
      json_match = content.match(/\{[\s\S]*\}/)
      if json_match
        parsed = JSON.parse(json_match[0])
        sources = parsed["sources"] || [parsed["source"]].compact

        # If sources is still empty, try to determine from verse reference
        if sources.empty?
          sources = [determine_source_from_reference(parsed["verse_reference"])]
        end

        {
          verse_reference: parsed["verse_reference"],
          original_text: parsed["original_text"],
          translation: parsed["translation"],
          explanation: parsed["explanation"],
          sources: sources,
          success: true
        }
      else
        # Fallback: parse the text manually
        parse_text_response(content)
      end
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse AI response as JSON: #{e.message}"
      parse_text_response(content)
    end
  end

  def determine_source_from_reference(verse_reference)
    return "Historical" unless verse_reference.present?

    verse_ref = verse_reference.to_s.downcase

    if verse_ref.include?("quran") || verse_ref.match?(/\d+:\d+/)
      "Quran"
    elsif verse_ref.include?("genesis") || verse_ref.include?("exodus") || verse_ref.include?("leviticus") ||
          verse_ref.include?("numbers") || verse_ref.include?("deuteronomy") || verse_ref.include?("joshua") ||
          verse_ref.include?("judges") || verse_ref.include?("ruth") || verse_ref.include?("samuel") ||
          verse_ref.include?("kings") || verse_ref.include?("chronicles") || verse_ref.include?("ezra") ||
          verse_ref.include?("nehemiah") || verse_ref.include?("esther") || verse_ref.include?("job") ||
          verse_ref.include?("psalms") || verse_ref.include?("proverbs") || verse_ref.include?("ecclesiastes") ||
          verse_ref.include?("song") || verse_ref.include?("isaiah") || verse_ref.include?("jeremiah") ||
          verse_ref.include?("lamentations") || verse_ref.include?("ezekiel") || verse_ref.include?("daniel") ||
          verse_ref.include?("hosea") || verse_ref.include?("joel") || verse_ref.include?("amos") ||
          verse_ref.include?("obadiah") || verse_ref.include?("jonah") || verse_ref.include?("micah") ||
          verse_ref.include?("nahum") || verse_ref.include?("habakkuk") || verse_ref.include?("zephaniah") ||
          verse_ref.include?("haggai") || verse_ref.include?("zechariah") || verse_ref.include?("malachi")
      "Tanakh"
    elsif verse_ref.include?("matthew") || verse_ref.include?("mark") || verse_ref.include?("luke") ||
          verse_ref.include?("john") || verse_ref.include?("acts") || verse_ref.include?("romans") ||
          verse_ref.include?("corinthians") || verse_ref.include?("galatians") || verse_ref.include?("ephesians") ||
          verse_ref.include?("philippians") || verse_ref.include?("colossians") || verse_ref.include?("thessalonians") ||
          verse_ref.include?("timothy") || verse_ref.include?("titus") || verse_ref.include?("philemon") ||
          verse_ref.include?("hebrews") || verse_ref.include?("james") || verse_ref.include?("peter") ||
          verse_ref.include?("john") || verse_ref.include?("jude") || verse_ref.include?("revelation")
      "Catholic" # Default to Catholic for New Testament
    else
      "Historical"
    end
  end

  def parse_text_response(content)
    # Fallback parsing for non-JSON responses
    lines = content.split("\n").map(&:strip).reject(&:empty?)

    verse_ref = lines.find { |line| line.match?(/reference|verse/i) } || "Verse Reference"
    original = lines.find { |line| line.match?(/original|arabic|hebrew|greek/i) } || "Original Text"
    translation = lines.find { |line| line.match?(/translation|english/i) } || "Translation"
    explanation = lines.find { |line| line.match?(/explanation|context/i) } || "Explanation"
    sources = [determine_source_from_reference(verse_ref)]

    {
      verse_reference: verse_ref,
      original_text: original,
      translation: translation,
      explanation: explanation,
      sources: sources,
      success: true
    }
  end

  def openai_client
    @openai_client ||= OpenAI::Client.new(access_token: openai_api_key)
  end

  def openai_api_key
    Rails.application.secrets.dig(:openai, :api_key)
  end
end
