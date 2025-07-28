class AiVerseEvidenceService
  AVAILABLE_SOURCES = ['Quran', 'Tanakh', 'Catholic', 'Ethiopian', 'Protestant', 'Historical']

  def initialize(claim_content)
    @claim_content = claim_content
  end

  def generate_verse_evidence(user_query = nil)
    prompt = build_prompt(user_query)

    begin
      response = openai_client.chat(
        parameters: {
          model: "gpt-4o",
          messages: [
            {
              role: "system",
              content: "You are an expert in religious texts and translations. Focus on providing accurate, literal translations from source languages (Arabic, Hebrew, Greek, etc.) with proper context. You must also identify the source of the verse from the available sources: #{AVAILABLE_SOURCES.join(', ')}."
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

      Please provide verse evidence with the following structure:

      1. **Verse Reference**: Include the exact verse name and number (e.g., "Quran 2:219", "Bible John 3:16", "Torah Genesis 1:1")
      2. **Original Text**: The text in its original language (Arabic, Hebrew, Greek, etc.)
      3. **Translation**: A direct, literal translation to English that maintains the original meaning
      4. **Explanation**: Brief explanation of the translation choices and context
      5. **Source**: Identify the source from these available options: #{AVAILABLE_SOURCES.join(', ')}

      Important guidelines:
      - Focus on literal, direct translation rather than interpretive translation
      - Include context from surrounding verses if needed for accurate translation
      - **CRITICAL**: You must identify the correct source based on the verse reference:
        * Quran verses (e.g., "Quran 2:219") → Source: "Quran"
        * Torah/Old Testament verses (e.g., "Genesis 1:1", "Exodus 20:1") → Source: "Tanakh"
        * New Testament verses (e.g., "John 3:16", "Matthew 5:1") → Source: "Catholic" (for Catholic Bible)
        * Ethiopian Orthodox verses → Source: "Ethiopian"
        * Protestant Bible verses → Source: "Protestant"
        * Historical religious texts → Source: "Historical"
      - Ensure the verse directly supports or relates to the claim
      - Provide accurate transliteration of the original text

      #{user_query ? "User specific request: #{user_query}" : ""}

      Please format your response as JSON:
      {
        "verse_reference": "Quran 2:219",
        "original_text": "Original text here",
        "translation": "English translation here",
        "explanation": "Explanation of translation choices and context",
        "source": "Quran"
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
        {
          verse_reference: parsed["verse_reference"],
          original_text: parsed["original_text"],
          translation: parsed["translation"],
          explanation: parsed["explanation"],
          source: parsed["source"] || determine_source_from_reference(parsed["verse_reference"]),
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

    reference = verse_reference.to_s.downcase

    case reference
    when /quran|koran/
      "Quran"
    when /genesis|exodus|leviticus|numbers|deuteronomy|torah|tanakh|old testament/
      "Tanakh"
    when /matthew|mark|luke|john|acts|romans|corinthians|galatians|ephesians|philippians|colossians|thessalonians|timothy|titus|philemon|hebrews|james|peter|john|jude|revelation|new testament/
      "Catholic" # Default to Catholic for New Testament
    when /ethiopian|geez/
      "Ethiopian"
    when /protestant|reformed/
      "Protestant"
    else
      "Historical"
    end
  end

  def parse_text_response(content)
    # Fallback parsing for non-JSON responses
    lines = content.split("\n").map(&:strip).reject(&:empty?)

    verse_ref = lines.find { |line| line.match?(/verse|reference|quran|bible/i) } || "Verse Reference"
    original = lines.find { |line| line.match?(/original|arabic|hebrew|greek/i) } || "Original text"
    translation = lines.find { |line| line.match?(/translation|english/i) } || "Translation"
    explanation = lines.find { |line| line.match?(/explanation|context/i) } || "Explanation"
    source = determine_source_from_reference(verse_ref)

    {
      verse_reference: verse_ref,
      original_text: original,
      translation: translation,
      explanation: explanation,
      source: source,
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
