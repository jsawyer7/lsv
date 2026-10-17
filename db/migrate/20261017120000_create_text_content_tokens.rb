class CreateTextContentTokens < ActiveRecord::Migration[7.0]
  # One row per word of a source text, kept verbatim from the source file
  # (e.g. MorphGNT SBLGNT). text_contents.content is the verse rebuilt from
  # these rows; nothing here is AI-generated.
  def change
    create_table :text_content_tokens do |t|
      t.references :text_content, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.integer :position, null: false   # 1-based word order within the verse
      t.string :ref, limit: 16, null: false # source reference as in the file, e.g. "010101"
      t.text :surface, null: false        # word exactly as printed, incl. punctuation and apparatus signs
      t.text :word, null: false           # punctuation and signs stripped
      t.text :normalized, null: false     # normalized form
      t.text :lemma, null: false          # dictionary form
      t.string :pos, limit: 8, null: false      # part of speech code, e.g. "V-"
      t.string :parsing, limit: 16, null: false # parsing code, e.g. "3AAI-S--"
      t.timestamps
    end

    add_index :text_content_tokens, [:text_content_id, :position], unique: true
    add_index :text_content_tokens, :lemma
  end
end
