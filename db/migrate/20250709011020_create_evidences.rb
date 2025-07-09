class CreateEvidences < ActiveRecord::Migration[7.0]
  def change
    create_table :evidences do |t|
      t.references :claim, null: false, foreign_key: true
      t.text :content
      t.integer :source

      t.timestamps
    end
  end
end
