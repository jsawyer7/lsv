module ClaimsHelper
  def format_ai_response(text)
    return ''.html_safe if text.blank?
    escaped = ERB::Util.html_escape(text)
    with_bold = escaped.gsub(/\*\*([^*]+)\*\*/m, '<strong>\1</strong>')
    simple_format(with_bold, {}, sanitize: false).html_safe
  end

  def format_ai_response_bold_only(text)
    return ''.html_safe if text.blank?
    escaped = ERB::Util.html_escape(text)
    escaped.gsub(/\*\*([^*]+)\*\*/m, '<strong>\1</strong>').html_safe
  end

  def ai_validator_source_label(source)
    case source.to_s
    when 'Quran' then 'Quran (Arabic)'
    when 'Tanakh' then 'Bible (Hebrew)'
    when 'Catholic' then 'Bible (Greek)'
    when 'Ethiopian', 'Protestant' then source.to_s
    when 'Historical' then 'Historical Usage'
    else source.to_s
    end
  end

  def ai_validator_verse_display(source, response_text)
    return '' if response_text.blank?
    text = response_text.strip
    case source.to_s
    when 'Quran'
      if text =~ /(Surah\s*\d+:\d+(?:\s*,\s*\d+:\d+)*)/i
        $1.strip
      elsif text =~ /(\d+:\d+(?:\s*,\s*\d+:\d+)*)/
        "Surah #{$1.strip}"
      else
        text.split(/\n+/).first.to_s.strip
      end
    when 'Tanakh', 'Catholic', 'Ethiopian', 'Protestant'
      text.split(/\n+/).first.to_s.strip
    when 'Historical'
      # One liner only: first sentence or first line
      first_sentence = text.split(/\.\s+/).first
      first_sentence = first_sentence.to_s.strip
      first_sentence += '.' unless first_sentence.end_with?('.')
      first_sentence
    else
      text.split(/\n+/).first.to_s.strip
    end
  end

  def ai_validator_lsv_source_name(source)
    case source.to_s
    when 'Quran' then 'Quran'
    when 'Tanakh', 'Catholic', 'Ethiopian', 'Protestant' then 'Bible'
    when 'Historical' then 'Historical Usage'
    else source.to_s
    end
  end

  def ai_validator_lsv_sources_phrase(primary_reasonings)
    return 'the cited sources' if primary_reasonings.blank?
    names = primary_reasonings.map { |r| ai_validator_lsv_source_name(r.source) }.uniq
    return 'the cited sources' if names.empty?
    case names.size
    when 1 then names.first
    when 2 then "both #{names.first} and #{names.last}"
    else "#{names[0..-2].join(', ')}, and #{names.last}"
    end
  end

  def ai_validator_lsv_line(claim, primary_reasonings)
    phrase = ai_validator_lsv_sources_phrase(primary_reasonings)
    "under Literal Source Verification for #{phrase}."
  end

  def ai_validator_verdict_real_text(primary_reasonings, tradition = 'actual')
    return '' if primary_reasonings.blank?
    combined = primary_reasonings.map { |r| r.response_for_tradition(tradition) }.join("\n\n").strip
    return combined if combined.blank?
    if combined =~ /Verdict:\s*(.+)/mi
      $1.strip
    else
      combined
    end
  end

  def claim_status_class(status)
    case status&.downcase
    when 'true'
      'success'
    when 'false'
      'danger'
    else
      'neutral'
    end
  end
end 