class AddSourceMarkupToTextContentTokens < ActiveRecord::Migration[7.0]
  # Extends text_content_tokens for the OSHB Hebrew OT (WLC) import:
  #   - Hebrew morphology is one combined code ("HR/Ncfsa"), so pos and
  #     normalized have no source value there; parsing needs more room (max 18).
  #   - kind distinguishes ordinary words from ketiv (written) and qere (read) forms.
  #   - source_word_id / source_n keep the file's id and n attributes.
  #   - source_xml keeps the exact original XML of each word, and of each verse
  #     on text_contents, so markup outside the plain text (large/small letters,
  #     notes, empty qere) is preserved byte-for-byte.
  def up
    change_column_null :text_content_tokens, :pos, true
    change_column_null :text_content_tokens, :normalized, true
    change_column :text_content_tokens, :parsing, :string, limit: 32, null: false

    add_column :text_content_tokens, :kind, :string, limit: 16, null: false, default: 'word'
    add_column :text_content_tokens, :source_word_id, :string, limit: 16
    add_column :text_content_tokens, :source_n, :string, limit: 16
    add_column :text_content_tokens, :source_xml, :text

    add_column :text_contents, :source_xml, :text
  end

  def down
    remove_column :text_contents, :source_xml

    remove_column :text_content_tokens, :source_xml
    remove_column :text_content_tokens, :source_n
    remove_column :text_content_tokens, :source_word_id
    remove_column :text_content_tokens, :kind

    change_column :text_content_tokens, :parsing, :string, limit: 16, null: false
    change_column_null :text_content_tokens, :normalized, false
    change_column_null :text_content_tokens, :pos, false
  end
end
