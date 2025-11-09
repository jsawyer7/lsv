class CreateCanonTextContents < ActiveRecord::Migration[7.0]
  def change
    create_table :canon_text_contents do |t|
      t.references :text_content, null: false, foreign_key: true, type: :uuid
      t.references :canon, null: false, foreign_key: true

      t.timestamps
    end
    
    add_index :canon_text_contents, [:text_content_id, :canon_id], unique: true
  end
end
