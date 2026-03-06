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
      refs = text.scan(/(?:1\s|2\s|3\s)?[A-Za-z]+\s+\d+:\d+/i).map(&:strip).uniq
      refs.reject! { |r| r =~ /\A(?:and|or|the|as|to|in|no|by|is|it|we|an)\s+/i }
      if refs.any?
        refs.join(', ')
      else
        # No verse ref found: show a short placeholder so bullet stays reference-only
        '—'
      end
    when 'Historical'
      if text =~ /(New\s+Testament)/i
        $1.strip
      elsif text =~ /([A-Za-z]+(?:\s+[A-Za-z]+)*,\s*\d+[\d.:\s]+)/
        $1.strip
      else
        first_phrase = text.split(/\.\s+/).first.to_s.strip
        first_phrase = first_phrase[0, 60] + '…' if first_phrase.length > 60
        first_phrase.presence || '—'
      end
    else
      refs = text.scan(/(?:1\s|2\s|3\s)?[A-Za-z]+\s+\d+:\d+/i).map(&:strip).uniq
      refs.any? ? refs.join(', ') : text.split(/\n+/).first.to_s.strip
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