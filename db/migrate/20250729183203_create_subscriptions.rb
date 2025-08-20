class CreateSubscriptions < ActiveRecord::Migration[7.0]
  def change
    create_table :subscriptions do |t|
      t.string :chargebee_id
      t.references :user, null: false, foreign_key: true
      t.references :plan, null: false, foreign_key: true
      t.string :status
      t.datetime :current_term_start
      t.datetime :current_term_end
      t.datetime :trial_start
      t.datetime :trial_end
      t.jsonb :metadata

      t.timestamps
    end
  end
end
