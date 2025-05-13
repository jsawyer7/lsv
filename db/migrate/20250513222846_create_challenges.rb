class CreateChallenges < ActiveRecord::Migration[7.0]
  def change
    create_table :challenges do |t|
      t.text :text, null: false
      t.text :ai_response
      t.string :status, default: 'pending'
      t.references :claim, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :challenges, [:claim_id, :user_id]
    add_index :challenges, :status
  end
end
