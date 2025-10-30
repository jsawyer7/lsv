class CreateTextTranslations < ActiveRecord::Migration[7.0]
  def change
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')

    create_table :text_translations, id: :uuid, default: 'gen_random_uuid()' do |t|
      # Parent link
      t.uuid :text_content_id, null: false

      # Target language (existing languages ids are bigints)
      t.references :language_target, null: false, foreign_key: { to_table: :languages }, type: :bigint

      # Core translation fields
      t.text :word_for_word_translation, null: false
      t.text :ai_translation, null: false
      t.text :ai_explanation, null: false

      # AI metadata
      t.string :ai_model_name, limit: 100
      t.decimal :ai_confidence_score, precision: 4, scale: 3

      # Audit / revision tracking
      t.integer :revision_number, null: false, default: 1
      t.boolean :is_latest, null: false, default: true
      t.datetime :confirmed_at
      t.string :confirmed_by, limit: 100
      t.text :notes

      t.timestamps
    end

    add_foreign_key :text_translations, :text_contents, column: :text_content_id
    add_index :text_translations, [:text_content_id, :revision_number], unique: true, name: 'index_text_translations_on_content_and_revision'
    add_index :text_translations, [:text_content_id, :is_latest], name: 'index_text_translations_on_content_latest'
  end
end


