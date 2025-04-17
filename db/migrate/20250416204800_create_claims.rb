class CreateClaims < ActiveRecord::Migration[7.0]
  def change
    create_table :claims do |t|
      t.references :user, null: false, foreign_key: true
      t.text :content
      t.text :evidence
      t.string :result
      t.text :reasoning

      t.timestamps
    end
  end
end
