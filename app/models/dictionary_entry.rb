# Wiktionary / Kaikki-style dictionary entry.
# raw_json is the letter-perfect JSONL line; payload is the parsed jsonb for search.
class DictionaryEntry < ApplicationRecord
  POS_OPTIONS = %w[
    adj adv adv_phrase article character circumfix conj contraction det infix
    interfix intj name noun num particle phrase postp prefix prep prep_phrase
    pron proverb punct suffix symbol verb
  ].freeze

  # Columns safe for the admin index (excludes multi-MB raw_json / payload).
  INDEX_COLUMNS = %w[
    id line_number word lang lang_code pos etymology_number
    source original_title senses_count created_at updated_at
  ].freeze

  validates :line_number, presence: true, uniqueness: true
  validates :word, :lang, :lang_code, :pos, :raw_json, :raw_sha256, :payload, presence: true

  scope :for_lang, ->(code) { where(lang_code: code) }
  scope :with_pos, ->(pos) { where(pos: pos) }
  scope :word_eq, ->(w) { where(word: w) }
  scope :word_prefix, ->(prefix) { where('word LIKE ?', "#{sanitize_sql_like(prefix)}%") }
  scope :word_continuous, ->(q) { where('word ILIKE ?', "%#{sanitize_sql_like(q)}%") }
  scope :for_index, -> { select(INDEX_COLUMNS.map { |c| "#{table_name}.#{c}" }) }

  def self.ransackable_attributes(_auth_object = nil)
    %w[id line_number word lang lang_code pos etymology_number source original_title senses_count created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  # Fast approximate row count from Postgres planner stats (avoids COUNT(*) on 1.5M+).
  def self.estimated_count
    connection.select_value(
      "SELECT COALESCE(reltuples, 0)::bigint FROM pg_class WHERE relname = #{connection.quote(table_name)}"
    ).to_i
  end

  def first_gloss
    senses = payload.is_a?(Hash) ? payload['senses'] : nil
    return nil unless senses.is_a?(Array) && senses.first.is_a?(Hash)

    glosses = senses.first['glosses']
    glosses.is_a?(Array) ? glosses.first : nil
  end

  def display_name
    "#{word} (#{pos})"
  end
end
