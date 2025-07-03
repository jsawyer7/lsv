class CreateReasonings < ActiveRecord::Migration[7.0]
  def change
    create_table :reasonings do |t|
      t.references :claim, null: false, foreign_key: true
      t.string :source, null: false
      t.text :response
      t.string :result
      t.timestamps
    end

    add_index :reasonings, [:claim_id, :source], unique: true
  end
end