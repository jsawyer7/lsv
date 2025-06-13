class CreateTheories < ActiveRecord::Migration[7.0]
  def change
    create_table :theories do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.string :status, default: 'in_review', null: false
      
      t.timestamps
    end
  end
end
