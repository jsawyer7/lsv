class AddDirectionAndScriptFieldsToLanguages < ActiveRecord::Migration[7.0]
  def change
    add_reference :languages, :direction, null: true, foreign_key: true
    add_column :languages, :script, :text
    add_column :languages, :font_stack, :text
    add_column :languages, :has_joining, :boolean, default: false
    add_column :languages, :uses_diacritics, :boolean, default: false
    add_column :languages, :has_cantillation, :boolean, default: false
    add_column :languages, :has_ayah_markers, :boolean, default: false
    add_column :languages, :native_digits, :boolean, default: false
    add_column :languages, :unicode_normalization, :text, default: 'NFC'
    add_column :languages, :shaping_engine, :text
    add_column :languages, :punctuation_mirroring, :boolean, default: false
  end
end
