class MoveWordForWordToTextContent < ActiveRecord::Migration[7.0]
  def change
    # Add word_for_word_translation to text_contents
    add_column :text_contents, :word_for_word_translation, :jsonb, default: []

    # Remove word_for_word_translation from text_translations
    remove_column :text_translations, :word_for_word_translation, :text
  end
end

